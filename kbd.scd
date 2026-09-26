// Dvorak layout, middle row of the keyboard are the white keys, top rows are black keys


(
// ---------- musical settings ----------
~scale = Scale.minorPentatonic;   // try Scale.dorian, Scale.aeolian
~root  = 48;                      // MIDI note
~oct   = 1;
~kbdInstr = \tonea;            // synthdef name

// typing keys -> scale degree index
~keyMap = IdentityDictionary[
    $a -> 0, $, -> 1, $o -> 2, $. -> 3, $e -> 4,
    $u -> 5, $y -> 6, $i -> 7, $f -> 8, $d -> 9,
    $g -> 10, $h -> 11, $t -> 12
];

// OSC button names -> same typing keys used by the GUI
~oscKeyMap = IdentityDictionary.new;
~oscKeyMap.put(\C, $a);
~oscKeyMap.put(\cs, $,);
~oscKeyMap.put(\D, $o);
~oscKeyMap.put(\ds, $.);
~oscKeyMap.put(\E, $e);
~oscKeyMap.put(\F, $u);
~oscKeyMap.put(\fs, $y);
~oscKeyMap.put(\G, $i);
~oscKeyMap.put(\gs, $f);
~oscKeyMap.put(\A, $d);
~oscKeyMap.put(\as, $g);
~oscKeyMap.put(\B, $h);

~oscKeyMap.put(\1, $a);
~oscKeyMap.put(\2, $o);
~oscKeyMap.put(\3, $e);
~oscKeyMap.put(\4, $u);
~oscKeyMap.put(\5, $i);
~oscKeyMap.put(\6, $d);
~oscKeyMap.put(\7, $h);

// TouchOSC 8x4 note grid: n11...n18, n21...n28, etc.
~touchOscNoteMap = IdentityDictionary.new;
4.do { |row|
    8.do { |column|
        ~touchOscNoteMap[("n" ++ (row + 1) ++ (column + 1)).asSymbol] = (row * 8) + column;
    };
};

(
// ---------- synth ----------
SynthDef(\kbdAmbient, { |out=0, freq=440, gate=1, amp=0.15, bright=2000, rq=0.25, pan=0|
    var sig, env, cutoff;

    sig = (VarSaw.ar(freq * [1, 1.003], 0, 0.3, 0.12).sum)
        + (SinOsc.ar(freq * 0.5, 0, 0.06));

    env = EnvGen.kr(Env.asr(0.5, 1, 3.5, curve: -4), gate, doneAction: 2);

    cutoff = (bright * (0.7 + SinOsc.kr(0.08).range(0, 0.6))).clip(60, 12000);
    sig = RLPF.ar(sig, cutoff, rq);

    sig = Pan2.ar((sig * env * amp), pan);
    // very stable reverb
    sig = sig + (FreeVerb2.ar(sig[0], sig[1], mix: 0.25, room: 0.9, damp: 0.5));

    sig = LeakDC.ar(sig);
    sig = HPF.ar(sig, 20);

    //sig = CheckBadValues.ar(sig, id: 999, post: 2); // will print if NaN/Inf appears
    sig = sig.tanh;
	// sig = sig + (JPverb.ar(sig, t60: 8, damp: 0.4, size: 2) * 0.35);


    Out.ar(out, sig);
}).add;
);

// ---------- state ----------
~held = IdentityDictionary.new;
~playbackHeld = IdentityDictionary.new;
~trackCount = 5;
~loopBars = 4;
~beatsPerBar = 4;
~loopBeats = ~loopBars * ~beatsPerBar;
~loopClock = TempoClock.new(2);
~loopTracks = Array.fill(~trackCount, { List.new });
~selectedTrack = 0;
~recording = false;
~playing = false;
~quantize = false;
~quantizeStep = 0.25;
~recordPending = IdentityDictionary.new;
~cycleStartBeat = ~loopClock.beats;
~transportRoutine = nil;

~loopPosition = {
    var position = (~loopClock.beats - ~cycleStartBeat) % ~loopBeats;
    if(~quantize) {
        position = (position / ~quantizeStep).round * ~quantizeStep;
    };
    position.clip(0, ~loopBeats - ~quantizeStep);
};

~recordNoteOn = { |ch, degree|
    if(~recording and: { ~playing }) {
        ~recordPending[ch] = [degree, ~loopPosition.(), ~selectedTrack];
    };
};

~recordNoteOff = { |ch|
    var pending = ~recordPending.removeAt(ch);
    var duration;
    if(pending.notNil) {
        duration = ~loopPosition.() - pending[1];
        if(duration <= 0) { duration = duration + ~loopBeats };
        if(~quantize) { duration = (duration / ~quantizeStep).round * ~quantizeStep };
        ~loopTracks[pending[2]].add([pending[1], duration.max(0.05), pending[0]]);
    };
};

~finishRecording = {
    ~recordPending.keys.asArray.do { |ch| ~recordNoteOff.(ch) };
};

~degreeToMidi = { |deg|
    var degrees = ~scale.degrees;
    var octAdd = (deg div: degrees.size) * 12;
    ~root + (~oct * 12) + degrees.wrapAt(deg) + octAdd;
};

~noteOn = { |ch, record=true|
    var midi;
    var deg = ~keyMap[ch];
    if(deg.isNil) { ^nil };
    if(~held[ch].notNil) { ^nil };

    midi = ~degreeToMidi.(deg);
    ~held[ch] = Synth(~kbdInstr, [
        \freq, midi.midicps,
        \amp, 0.9
    ]);
    if(record) { ~recordNoteOn.(ch, deg) };
};

~noteOff = { |ch|
    var syn = ~held[ch];
    if(syn.notNil) {
        ~recordNoteOff.(ch);
        syn.set(\gate, 0);
        ~held.removeAt(ch);
    };
};

~panic = {
    ~finishRecording.();
    ~held.values.do { |syn| syn.set(\gate, 0) };
    ~held.clear;
    ~playbackHeld.values.do { |syn| syn.set(\gate, 0) };
    ~playbackHeld.clear;
    "panic: all notes off".postln;
};

~playTrack = { |trackIndex|
    ~loopTracks[trackIndex].do { |event, eventIndex|
        ~loopClock.sched(event[0], {
            var key = ("play_" ++ trackIndex ++ "_" ++ eventIndex).asSymbol;
            var synth = Synth(~kbdInstr, [\freq, ~degreeToMidi.(event[2]).midicps, \amp, 0.9]);
            ~playbackHeld[key] = synth;
            ~loopClock.sched(event[1], {
                synth.set(\gate, 0);
                ~playbackHeld.removeAt(key);
                nil;
            });
            nil;
        });
    };
};

~playCycle = {
    ~cycleStartBeat = ~loopClock.beats;
    ~trackCount.do { |trackIndex| ~playTrack.(trackIndex) };
};

~startTransport = {
    if(~playing.not) {
        ~playing = true;
        ~transportRoutine = Routine({
            loop {
                ~playCycle.();
                ~loopBeats.wait;
            };
        }).play(~loopClock, quant: 1);
    };
};

~stopTransport = {
    if(~playing) {
        if(~recording) { ~finishRecording.() };
        ~recording = false;
        ~playing = false;
        ~transportRoutine.stop;
        ~transportRoutine = nil;
        ~playbackHeld.values.do { |syn| syn.set(\gate, 0) };
        ~playbackHeld.clear;
    };
};

~toggleRecording = {
    if(~recording) { ~finishRecording.() } { ~startTransport.() };
    ~recording = ~recording.not;
};

~clearSelectedTrack = {
    ~loopTracks[~selectedTrack].clear;
};

~dumpTracks = {
    "~loopPatterns = [".postln;
    ~loopTracks.do { |track, trackIndex|
        if(track.isEmpty) {
            "  Pbind(\\type, \\rest, \\dur, %)%"
            .format(~loopBeats, if(trackIndex < (~trackCount - 1)) { "," } { "" }).postln;
        } {
            var patterns = track.collect { |event|
                "Pseq([Pbind(\\type, \\rest, \\dur, %), Pbind(\\instrument, ~kbdInstr, \\degree, %, \\dur, %, \\legato, 1)], 1)"
                .format(event[0], event[2], event[1]);
            };
            "  Pseq([Ppar([".post;
            patterns.join(", ").post;
            "]), Pbind(\\type, \\rest, \\dur, %)], inf)%"
            .format((~loopBeats - track.collect { |event| event[0] + event[1] }.maxItem).max(0), if(trackIndex < (~trackCount - 1)) { "," } { "" }).postln;
        };
    };
    "];".postln;
};

~oscKeyAction = { |msg|
    var key = msg[0].asString.split($/).last.asSymbol;
    var ch = ~oscKeyMap[key];
    var value = msg[1];
	// "key % value % ch %".format(key, value, ch).postln;

    if(ch.notNil) {
        if(value == 0) {
            ~noteOff.(ch);
        } {
            ~noteOn.(ch);
        };
    };
};

~oscKeyResponders = ~oscKeyMap.keys.collect { |key|
    OSCdef(("kbd_" ++ key.asString).asSymbol, ~oscKeyAction, ("/keys/" ++ key.asString).asSymbol);
};

~touchOscNoteAction = { |msg|
    var key = msg[0].asString.split($/).last.asSymbol;
    var value = msg[1];

    if(~touchOscNoteMap[key].notNil) {
        if(value == 0) {
            ~noteOff.(key);
        } {
            ~noteOn.(key);
        };
    };
};

~touchOscNoteResponders = ~touchOscNoteMap.keys.collect { |key|
    ~keyMap[key] = ~touchOscNoteMap[key];
    OSCdef(("touchOsc_" ++ key.asString).asSymbol, ~touchOscNoteAction, ("/notes/" ++ key.asString).asSymbol);
};

OSCdef(\push1, ~oscKeyAction, '/group7/C');
OSCdef(\push2, ~oscKeyAction, '/group7/D');
OSCdef(\push3, ~oscKeyAction, '/group7/E');
OSCdef(\push4, ~oscKeyAction, '/group7/F');
OSCdef(\push5, ~oscKeyAction, '/group7/G');
OSCdef(\push6, ~oscKeyAction, '/group7/A');
OSCdef(\push7, ~oscKeyAction, '/group7/B');

// ---------- GUI ----------
~w = Window("SC typing keyboard looper", Rect(100, 100, 640, 310)).front;
~w.view.background = Color.gray(0.15);

StaticText(~w, Rect(10, 10, 620, 18))
.string_("Play: a , o . e u y i f d g h t | Octave: [ ] | Root: - = | Panic: \\")
.stringColor_(Color.white);

~status = StaticText(~w, Rect(10, 32, 620, 18)).stringColor_(Color.gray(0.9));

~looperDisplay = StaticText(~w, Rect(10, 57, 620, 132))
.font_(Font("Menlo", 12))
.stringColor_(Color(0.65, 0.95, 0.7));

~playButton = Button(~w, Rect(10, 200, 85, 26))
.states_([["PLAY", Color.white, Color.gray(0.3)], ["STOP", Color.white, Color(0.6, 0.2, 0.2)]])
.action_({ |button|
    if(button.value == 1) { ~startTransport.() } { ~stopTransport.() };
    ~recordButton.value = ~recording.binaryValue;
    ~updateLooperDisplay.();
});

~recordButton = Button(~w, Rect(105, 200, 85, 26))
.states_([["REC", Color.white, Color.gray(0.3)], ["RECORDING", Color.white, Color.red]])
.action_({ |button|
    ~toggleRecording.();
    button.value = ~recording.binaryValue;
    ~playButton.value = ~playing.binaryValue;
    ~updateLooperDisplay.();
});

~quantizeButton = Button(~w, Rect(200, 200, 85, 26))
.states_([["QUANT: OFF", Color.white, Color.gray(0.3)], ["QUANT: 1/16", Color.black, Color(0.85, 0.75, 0.25)]])
.action_({ |button|
    ~quantize = button.value == 1;
    ~updateLooperDisplay.();
});

Button(~w, Rect(295, 200, 85, 26))
.states_([["CLEAR TRACK", Color.white, Color(0.5, 0.2, 0.2)]])
.action_({ ~clearSelectedTrack.(); ~updateLooperDisplay.() });

Button(~w, Rect(390, 200, 85, 26))
.states_([["DUMP PATS", Color.white, Color(0.25, 0.4, 0.25)]])
.action_({ ~dumpTracks.() });

~trackButtons = ~trackCount.collect { |trackIndex|
    Button(~w, Rect(10 + (trackIndex * 95), 237, 85, 26))
    .states_([["TRACK " ++ (trackIndex + 1), Color.white, Color.gray(0.28)]])
    .action_({
        ~selectedTrack = trackIndex;
        ~updateLooperDisplay.();
    });
};

~updateStatus = {
    ~status.string = "root: % , scale: %, octave: %"
    .format(~root, ~scale.name, ~oct);
};

~updateLooperDisplay = {
    var position = if(~playing) { ~loopPosition.() } { 0 };
    var bar = (position div: ~beatsPerBar) + 1;
    var beat = (position % ~beatsPerBar).floor + 1;
    var mode = if(~recording) { "RECORDING" } { if(~playing) { "PLAYING  " } { "STOPPED  " } };
    var lines = List.new;
    lines.add("+----------------------------------------------------------+");
    lines.add("| LOOP: %/%  BAR: %/%  BEAT: %  MODE: %  Q: % |"
        .format(~loopBars, ~loopBars, bar, ~loopBars, beat, mode, if(~quantize) { "1/16" } { "OFF " }));
    lines.add("+----------------------------------------------------------+");
    ~trackCount.do { |trackIndex|
        var selected = if(trackIndex == ~selectedTrack) { ">" } { " " };
        var armed = if(~recording and: { trackIndex == ~selectedTrack }) { "REC" } { "   " };
        lines.add("| % TRACK %  [%]  EVENTS: %                           |"
            .format(selected, trackIndex + 1, armed, ~loopTracks[trackIndex].size));
    };
    lines.add("+----------------------------------------------------------+");
    ~looperDisplay.string = lines.join(Char.nl);
};
~updateStatus.();
~updateLooperDisplay.();

~displayRoutine = Routine({
    loop {
        { ~updateLooperDisplay.() }.defer;
        0.05.wait;
    };
}).play(AppClock);

~w.view.keyDownAction = { |view, char, mod, unicode, keycode|
    switch(char,
        $[, { ~oct = (~oct - 1).clip(-4, 4); ~updateStatus.(); },
        $], { ~oct = (~oct + 1).clip(-4, 4); ~updateStatus.(); },
        $-, { ~root = (~root - 1).clip(0, 127); ~updateStatus.(); },
        $=, { ~root = (~root + 1).clip(0, 127); ~updateStatus.(); },
        $\\, { ~panic.(); },
		$l, { ~panic.(); ~reload.(); },
		{ ~noteOn.(char); ~status.string = "char: %".format(char) }
    );
};

~w.view.keyUpAction = { |view, char, mod, unicode, keycode|
    ~noteOff.(char);
};

~w.onClose_({
    ~oscKeyResponders.do(_.free);
    ~touchOscNoteResponders.do(_.free);
    ~displayRoutine.stop;
    ~stopTransport.();
    ~panic.();
});

)

// ---------- GUI ----------

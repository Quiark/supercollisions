// Dvorak layout, middle row of the keyboard are the white keys, top rows are black keys


(
// ---------- musical settings ----------
~scale = Scale.major;   // try Scale.dorian, Scale.aeolian
~root  = 36;                      // MIDI note
~oct   = 1;
~kbdInstr = \stones;            // synthdef name

// typing keys -> scale degree index
~keyMap = IdentityDictionary[
    $a -> 0, $, -> 1, $o -> 2, $. -> 3, $e -> 4,
    $u -> 5, $y -> 6, $i -> 7, $f -> 8, $d -> 9,
    $g -> 10, $h -> 11, $t -> 12
];

// Named OSC controls reuse the typing keyboard layout.
~oscKeyMap = IdentityDictionary[
    \C -> $a, \cs -> $,, \D -> $o, \ds -> $., \E -> $e,
    \F -> $u, \fs -> $y, \G -> $i, \gs -> $f, \A -> $d,
    \as -> $g, \B -> $h,
    \1 -> $a, \2 -> $o, \3 -> $e, \4 -> $u, \5 -> $i,
    \6 -> $d, \7 -> $h
];

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
~noteParams = (lpf: 0.5, lpfq: 0, detune: 0.5, lfodep: 0.9, lforate: 0.5, alpha: 0, beta: 0);
~cutoffMonitorNode = nil;
~logwrap = 0;
~touchOscMode = \play;
if(~arpPlayers.notNil) { ~arpPlayers.values.do(_.stop) };
~arpPatternButtons = IdentityDictionary[
    \n11 -> \p11,
    \n12 -> \p12,
    \n13 -> \p13,
    \n14 -> \p14
];
~arpPlayers = IdentityDictionary.new;

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

~noteArgs = { |degree|
    var args = [\freq, ~degreeToMidi.(degree).midicps, \amp, 0.9];
    ~noteParams.keysValuesDo { |key, value| args = args.add(key).add(value) };
    args;
};

~makeArpPattern = { |degrees|
    Pbind(
        \instrument, Pfunc { ~kbdInstr },
        \degree, Pseq(degrees, inf),
        \freq, Pfunc { |event| ~degreeToMidi.(event[\degree]).midicps },
        \dur, 1/4,
        \legato, 0.75,
        \rls, 0.3,
        \amp, 0.14,
        \lpf, Pfunc { ~noteParams[\lpf] },
        \lpfq, Pfunc { ~noteParams[\lpfq] },
        \detune, Pfunc { ~noteParams[\detune] },
        \lfodep, Pfunc { ~noteParams[\lfodep] },
        \lforate, Pfunc { ~noteParams[\lforate] },
        \alpha, Pfunc { ~noteParams[\alpha] },
        \beta, Pfunc { ~noteParams[\beta] }
    );
};

// typical patterns:
// [1, 3, 5, 7] - major arpeggio
// [1, 2, 3, 6] - minor arpeggio
// ;e
Pdef(\p11, ~makeArpPattern.([1, 3, 5, 7]));
Pdef(\p12, ~makeArpPattern.([1, 2, 3, 6]));
Pdef(\p13, ~makeArpPattern.([0, 2, 12, 10, 35]));
Pdef(\p14, ~makeArpPattern.([14, 21, 16, 18, 14, 18, 21, 16]));

~stopArpPatterns = {
    ~arpPlayers.values.do(_.stop);
    ~arpPlayers.clear;
};

~toggleArpPattern = { |key|
    var player = ~arpPlayers[key];
    if(player.notNil) {
        player.stop;
        ~arpPlayers.removeAt(key);
    } {
        ~arpPlayers[key] = Pdef(key).play(~loopClock, quant: ~beatsPerBar);
    };
};

~noteOn = { |id, degree, record=true|
	var syn;
    if(degree.isNil) { ^nil };
    if(~held[id].notNil) { ^nil };
	" : ".post; ~degreeToMidi.(degree).post; 
	~logwrap = ~logwrap + 1;
	if(~logwrap > 10, { ~logwrap = 0; "\n".post; });

    syn = Synth(~kbdInstr, ~noteArgs.(degree));
    ~held[id] = syn;
    if(~cutoffMonitorNode.isNil) {
        ~cutoffMonitorNode = syn.nodeID;
        syn.set(\cutoffMonitor, 1);
    };
    if(record) { ~recordNoteOn.(id, degree) };
};

~noteOff = { |id|
    var syn = ~held[id];
    if(syn.notNil) {
        ~recordNoteOff.(id);
		if(syn.nodeID == ~cutoffMonitorNode) {
			~cutoffMonitorNode = nil;
			syn.set(\cutoffMonitor, 0);
		};
        syn.set(\gate, 0);
        ~held.removeAt(id);
    };
};

~panic = {
    ~finishRecording.();
    ~held.values.do { |syn| syn.set(\gate, 0) };
    ~held.clear;
	~cutoffMonitorNode = nil;
    ~stopArpPatterns.();
    ~playbackHeld.values.do { |syn| syn.set(\gate, 0) };
    ~playbackHeld.clear;
    "panic: all notes off".postln;
};

~playTrack = { |trackIndex|
    ~loopTracks[trackIndex].do { |event, eventIndex|
        ~loopClock.sched(event[0], {
            var key = ("play_" ++ trackIndex ++ "_" ++ eventIndex).asSymbol;
            var synth = Synth(~kbdInstr, ~noteArgs.(event[2]));
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

~timelineString = { |cells|
    cells.clump(~beatsPerBar).collect { |bar| bar.join }.join("|");
};

~trackTimeline = { |track|
    var cells = Array.fill(~loopBeats, { "." });
    track.do { |event|
        var start = event[0].floor.asInteger;
        var length = event[1].ceil.asInteger.max(1);
        length.do { |offset|
            cells.put((start + offset) % ~loopBeats, "▓");
        };
    };
    ~timelineString.(cells);
};

~playheadTimeline = { |position|
    ~timelineString.(Array.fill(~loopBeats, { |index|
        if(index == position.floor.asInteger) { "^" } { " " };
    }));
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

~oscNoteAction = { |msg, time, addr, degree|
    var value = msg[1];
    var id = "%:%:%".format(addr.ip, addr.port, msg[0]).asSymbol;

    if(value == 0) {
        ~noteOff.(id);
    } {
        ~noteOn.(id, degree);
    };
};

// Vorg file
~oscKeyResponders = ~oscKeyMap.keys.collect { |key|
    var degree = ~keyMap[~oscKeyMap[key]];
    OSCdef(("kbd_" ++ key.asString).asSymbol, { |msg, time, addr|
        ~oscNoteAction.(msg, time, addr, degree);
    }, ("/keys/" ++ key.asString).asSymbol);
};

// TouchOSC grid, 4 rows x 8 columns, tomae file
~touchOscNoteResponders = 4.collect { |row|
    8.collect { |column|
        var key = ("n" ++ (row + 1) ++ (column + 1)).asSymbol;
        var degree = (row * 7) + column;
        OSCdef(("touchOsc_" ++ key.asString).asSymbol, { |msg, time, addr|
            var value = msg[1].asFloat;
            var pattern = ~arpPatternButtons[key];
            if(value <= 0) {
                ~oscNoteAction.(msg, time, addr, degree);
            } {
                if(~touchOscMode == \play) {
                    ~oscNoteAction.(msg, time, addr, degree);
                } {
                    if(pattern.notNil) { ~toggleArpPattern.(pattern) };
                };
            };
        }, ("/notes/" ++ key.asString).asSymbol);
    };
}.flat;

~touchOscModeResponders = [
    OSCdef(\mPlay, { |msg|
		msg.postln;
        if(msg[1].asFloat > 0.5) { ~touchOscMode = \play };
    }, '/mPlay'),
    OSCdef(\mTog, { |msg|
		msg.postln;
        if(msg[1].asFloat > 0.5) { ~touchOscMode = \toggle };
    }, '/mTog')
];

// Beatmachine, page 2 group 7
~pushResponders = [\C, \D, \E, \F, \G, \A, \B].collect { |key, index|
    var degree = [0, 2, 4, 5, 7, 9, 11][index];
    OSCdef(("push_" ++ key.asString).asSymbol, { |msg, time, addr|
        ~oscNoteAction.(msg, time, addr, degree);
    }, ("/group7/" ++ key.asString).asSymbol);
};

~noteParamResponders = ~noteParams.keys.collect { |key|
    OSCdef(("kbdParam_" ++ key).asSymbol, { |msg|
        ~noteParams[key] = msg[1];
    }, "/" ++ key);
};

~cutoffResponder = OSCdef(\stonesCutoff, { |msg|
    var cutoff = msg[3];
    {
        ~cutoffMeter.value = cutoff.explin(20, 12000, 0, 1).clip(0, 1);
        ~cutoffLabel.string = "CUTOFF: % Hz".format(cutoff.round(1));
    }.defer;
}, '/stones/cutoff');

// ---------- GUI ----------
~w = Window("SC typing keyboard looper", Rect(100, 100, 640, 337)).front;
~w.view.background = Color.gray(0.15);

StaticText(~w, Rect(10, 10, 620, 18))
.string_("Play: a , o . e u y i f d g h t | Octave: [ ] | Root: - = | Panic: \\")
.stringColor_(Color.white);

~status = StaticText(~w, Rect(10, 32, 620, 18)).stringColor_(Color.gray(0.9));

~looperDisplay = StaticText(~w, Rect(10, 57, 620, 160))
.font_(Font("Menlo", 12))
.stringColor_(Color(0.65, 0.95, 0.7));

~playButton = Button(~w, Rect(10, 228, 85, 26))
.states_([["PLAY", Color.white, Color.gray(0.3)], ["STOP", Color.white, Color(0.6, 0.2, 0.2)]])
.action_({ |button|
    if(button.value == 1) { ~startTransport.() } { ~stopTransport.() };
    ~recordButton.value = ~recording.binaryValue;
    ~updateLooperDisplay.();
});

~recordButton = Button(~w, Rect(105, 228, 85, 26))
.states_([["REC", Color.white, Color.gray(0.3)], ["RECORDING", Color.white, Color.red]])
.action_({ |button|
    ~toggleRecording.();
    button.value = ~recording.binaryValue;
    ~playButton.value = ~playing.binaryValue;
    ~updateLooperDisplay.();
});

~quantizeButton = Button(~w, Rect(200, 228, 85, 26))
.states_([["QUANT: OFF", Color.white, Color.gray(0.3)], ["QUANT: 1/16", Color.black, Color(0.85, 0.75, 0.25)]])
.action_({ |button|
    ~quantize = button.value == 1;
    ~updateLooperDisplay.();
});

Button(~w, Rect(295, 228, 85, 26))
.states_([["CLEAR TRACK", Color.white, Color(0.5, 0.2, 0.2)]])
.action_({ ~clearSelectedTrack.(); ~updateLooperDisplay.() });

Button(~w, Rect(390, 228, 85, 26))
.states_([["DUMP PATS", Color.white, Color(0.25, 0.4, 0.25)]])
.action_({ ~dumpTracks.() });

~trackButtons = ~trackCount.collect { |trackIndex|
    Button(~w, Rect(10 + (trackIndex * 95), 265, 85, 26))
    .states_([["TRACK " ++ (trackIndex + 1), Color.white, Color.gray(0.28)]])
    .action_({
        ~selectedTrack = trackIndex;
        ~updateLooperDisplay.();
    });
};

~cutoffLabel = StaticText(~w, Rect(485, 228, 145, 18))
.string_("CUTOFF: -- Hz")
.stringColor_(Color(0.65, 0.95, 0.7));

~cutoffMeter = LevelIndicator(~w, Rect(485, 251, 145, 16))
.warning_(0.75)
.critical_(0.9)
.drawsPeak_(false);

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
    lines.add("+-------------------------------------+");
    lines.add("| BAR: %/%  BEAT: %  %  Q:% |"
        .format(bar, ~loopBars, beat, mode, if(~quantize) { "1/16" } { "OFF " }));
    lines.add("| TRACK     |1234|1234|1234|1234|");
    lines.add("+------------+----+----+----+----+");
    ~trackCount.do { |trackIndex|
        var selected = if(trackIndex == ~selectedTrack) { ">" } { " " };
        var armed = if(~recording and: { trackIndex == ~selectedTrack }) { "REC" } { "   " };
        lines.add("| % T% [%] |%|"
            .format(selected, trackIndex + 1, armed, ~trackTimeline.(~loopTracks[trackIndex])));
    };
	lines.add("| PLAYHEAD   |%|".format(~playheadTimeline.(position)));
    lines.add("+------------+----+----+----+----+");
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
		{ ~noteOn.(char, ~keyMap[char]); ~status.string = "char: %".format(char) }
    );
};

~w.view.keyUpAction = { |view, char, mod, unicode, keycode|
    ~noteOff.(char);
};

~w.onClose_({
    ~oscKeyResponders.do(_.free);
    ~touchOscNoteResponders.do(_.free);
    ~touchOscModeResponders.do(_.free);
    ~pushResponders.do(_.free);
	~noteParamResponders.do(_.free);
    ~cutoffResponder.free;
    ~displayRoutine.stop;
    ~stopTransport.();
    ~panic.();
});

)

// ---------- GUI ----------

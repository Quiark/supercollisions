// Dvorak layout, middle row of the keyboard are the white keys, top rows are black keys


(
// ---------- musical settings ----------
~scale = Scale.major;   // try Scale.dorian, Scale.aeolian
~baseMidi = 48;
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
~heldDegrees = IdentityDictionary.new;
~heldSharpCapable = IdentityDictionary.new;
~heldChords = IdentityDictionary.new;
~sharpHeld = false;
~chordMode = 0;
~loopClock = TempoClock.new(2);
~trackNames = [\arp1, \bass, \pad, \melody];
~trackDegrees = Array.fill(~trackNames.size, { List.new });
~trackIndices = Array.fill(~trackNames.size, 0);
// Track roots are MIDI base notes.
~trackRoots = Array.fill(~trackNames.size, { ~baseMidi });
~arpDegrees = ~trackDegrees[0];
~selectedTrack = 0;
~recording = false;
~playing = false;
~touchOscMode = \play;
if(~trackPlayers.notNil) { ~trackPlayers.values.do(_.stop) };
~trackPlayers = IdentityDictionary.new;
~trackNoteParams = Array.fill(~trackNames.size, {
    (lpf: 0.5, lpfq: 0, detune: 0.5, lfodep: 0.9, lforate: 0.5, alpha: 0, beta: 0, amp: 0.33)
});
~noteParams = ~trackNoteParams[~selectedTrack];
~cutoffMonitorNode = nil;
~logwrap = 0;

~degreeToMidi = { |deg|
    var degrees = ~scale.degrees;
    var octAdd = (deg div: degrees.size) * 12;
    ~baseMidi + degrees.wrapAt(deg) + octAdd;
};

~trackDegreeToMidi = { |trackIndex, degree|
    var degrees = ~scale.degrees;
    var octAdd = (degree div: degrees.size) * 12;
    ~trackRoots[trackIndex] + degrees.wrapAt(degree) + octAdd;
};

~noteArgs = { |degree, sharp=false|
    var args = [\freq, (~degreeToMidi.(degree) + sharp.binaryValue).midicps, \amp, 0.9];
    ~noteParams.keysValuesDo { |key, value| args = args.add(key).add(value) };
    args;
};

~makeArpPattern = { |trackIndex|
    Pbind(
        \instrument, Pfunc { ~kbdInstr },
        \degree, Pfunc {
            var degree;
            if(~trackDegrees[trackIndex].isEmpty) {
                \rest
            } {
                degree = ~trackDegrees[trackIndex].wrapAt(~trackIndices[trackIndex]);
                ~trackIndices[trackIndex] = ~trackIndices[trackIndex] + 1;
                degree;
            };
        },
        \freq, Pfunc { |event|
            if(event[\degree] == \rest) { 0 } { ~trackDegreeToMidi.(trackIndex, event[\degree]).midicps };
        },
        \dur, 1/4,
        \legato, 0.75,
        \rls, 0.3,
        \amp, Pfunc { ~trackNoteParams[trackIndex][\amp] },
        \lpf, Pfunc { ~trackNoteParams[trackIndex][\lpf] },
        \lpfq, Pfunc { ~trackNoteParams[trackIndex][\lpfq] },
        \detune, Pfunc { ~trackNoteParams[trackIndex][\detune] },
        \lfodep, Pfunc { ~trackNoteParams[trackIndex][\lfodep] },
        \lforate, Pfunc { ~trackNoteParams[trackIndex][\lforate] },
        \alpha, Pfunc { ~trackNoteParams[trackIndex][\alpha] },
        \beta, Pfunc { ~trackNoteParams[trackIndex][\beta] }
    );
};

~trackNames.do { |name, trackIndex| Pdef(name, ~makeArpPattern.(trackIndex)) };

~recordDegree = { |degree|
    if(~recording) { ~trackDegrees[~selectedTrack].add(degree) };
};

~setSharpForHeldNotes = {
    ~held.keysValuesDo { |id, syn|
        if(~heldSharpCapable[id]) {
            syn.set(\freq, (~degreeToMidi.(~heldDegrees[id]) + ~sharpHeld.binaryValue).midicps);
        };
    };
    ~heldChords.values.do { |chord|
        chord[\synths].do { |syn, index|
            syn.set(\freq, (~degreeToMidi.(chord[\degrees][index]) + ~sharpHeld.binaryValue).midicps);
        };
    };
};

~noteOn = { |id, degree, record=true, sharpCapable=false|
	var syn;
    if(degree.isNil) { ^nil };
    if(~held[id].notNil) { ^nil };
	" : ".post; ~degreeToMidi.(degree).post; 
	~logwrap = ~logwrap + 1;
	if(~logwrap > 10, { ~logwrap = 0; "\n".post; });

    syn = Synth(~kbdInstr, ~noteArgs.(degree, sharpCapable and: { ~sharpHeld }));
    ~held[id] = syn;
    ~heldDegrees[id] = degree;
    ~heldSharpCapable[id] = sharpCapable;
    if(~cutoffMonitorNode.isNil) {
        ~cutoffMonitorNode = syn.nodeID;
        syn.set(\cutoffMonitor, 1);
    };
    if(record) { ~recordDegree.(degree) };
};

~noteOff = { |id|
    var syn = ~held[id];
    if(syn.notNil) {
		if(syn.nodeID == ~cutoffMonitorNode) {
			~cutoffMonitorNode = nil;
			syn.set(\cutoffMonitor, 0);
		};
        syn.set(\gate, 0);
        ~held.removeAt(id);
        ~heldDegrees.removeAt(id);
        ~heldSharpCapable.removeAt(id);
    };
};

~chordNoteOn = { |id, degree|
    var degrees, synths;
    if(~held[id].notNil or: { ~heldChords[id].notNil }) { ^nil };

    degrees = if(~chordMode == 1) {
        [degree, degree + 2, degree + 4]
    } {
        [degree, degree + 2, degree + 4, degree + 6]
    };
    synths = degrees.collect { |chordDegree|
        Synth(~kbdInstr, ~noteArgs.(chordDegree, ~sharpHeld));
    };
    ~heldChords[id] = (synths: synths, degrees: degrees);
    if(~cutoffMonitorNode.isNil) {
        ~cutoffMonitorNode = synths[0].nodeID;
        synths[0].set(\cutoffMonitor, 1);
    };
    ~recordDegree.(degree);
};

~chordNoteOff = { |id|
    var chord = ~heldChords[id];
    if(chord.notNil) {
        chord[\synths].do { |syn|
            if(syn.nodeID == ~cutoffMonitorNode) { ~cutoffMonitorNode = nil };
            syn.set(\gate, 0);
        };
        ~heldChords.removeAt(id);
    };
};

~panic = {
    ~held.values.do { |syn| syn.set(\gate, 0) };
    ~heldChords.values.do { |chord| chord[\synths].do { |syn| syn.set(\gate, 0) } };
    ~held.clear;
	~heldDegrees.clear;
	~heldSharpCapable.clear;
	~heldChords.clear;
	~cutoffMonitorNode = nil;
    "panic: all notes off".postln;
};

~toggleRecording = {
    ~recording = ~recording.not;
};

~clearSelectedTrack = {
    ~trackDegrees[~selectedTrack].clear;
    ~trackIndices[~selectedTrack] = 0;
};

~transposeSelectedTrack = { |degree|
    if(degree != \rest) { ~trackRoots[~selectedTrack] = ~degreeToMidi.(degree) };
};

~selectTrack = { |trackIndex|
    ~selectedTrack = trackIndex;
    ~noteParams = ~trackNoteParams[trackIndex];
};

~startTransport = {
    if(~playing.not) {
        ~trackNames.do { |name| ~trackPlayers[name] = Pdef(name).play(~loopClock) };
        ~playing = true;
    };
};

~stopTransport = {
    ~trackPlayers.values.do(_.stop);
    ~trackPlayers.clear;
    ~playing = false;
};

~oscNoteAction = { |msg, time, addr, degree|
    var value = msg[1];
    var id = "%:%:%".format(addr.ip, addr.port, msg[0]).asSymbol;

    if(value == 0) {
        ~noteOff.(id);
    } {
        if(degree == \rest) { ~recordDegree.(degree) } { ~noteOn.(id, degree, true, true) };
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
        var degree = if(column == 7) { \rest } { (row * 7) + column };
        OSCdef(("touchOsc_" ++ key.asString).asSymbol, { |msg, time, addr|
            var value = msg[1].asFloat;
            var id = "%:%:%".format(addr.ip, addr.port, msg[0]).asSymbol;
            if(value == 0) {
                ~noteOff.(id);
                ~chordNoteOff.(id);
            } {
            if(~touchOscMode == \transpose) {
                ~transposeSelectedTrack.(degree);
            } {
                if((~chordMode > 0) and: { degree != \rest }) {
                    ~chordNoteOn.(id, degree);
                } {
                    ~oscNoteAction.(msg, time, addr, degree);
                };
            };
            };
        }, ("/notes/" ++ key.asString).asSymbol);
    };
}.flat;

~touchOscModeResponder = OSCdef(\mTranspose, { |msg|
    ~touchOscMode = if(msg[1].asFloat > 0.5) { \transpose } { \play };
    { ~updateLooperDisplay.() }.defer;
}, '/mTranspose');

~sharpResponder = OSCdef(\mSharp, { |msg|
    ~sharpHeld = msg[1].asFloat > 0.5;
    ~setSharpForHeldNotes.();
}, '/mSharp');

~chordsResponder = OSCdef(\mChords, { |msg|
    if(msg[1].asFloat > 0.5) {
        ~chordMode = (~chordMode + 1) % 3;
    };
}, '/mChords');

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

OSCdef(\masterReverbGamma, { |msg|
    ~masterReverb.set(\damp, msg[1].asFloat.clip(0, 1));
}, '/gamma');

if(~masterReverb.notNil) { ~masterReverb.free };
SynthDef(\masterReverb, { |out=0, mix=0.28, room=0.88, damp=0.45, amp=1|
	var input, signal;
	input = In.ar(out, 2);
	signal = FreeVerb2.ar(input[0], input[1], mix, room, damp);
	ReplaceOut.ar(out, LeakDC.ar(signal) * amp);
}).add;
~masterReverb = Synth.tail(s, \masterReverb);

~selectTrack.(0);
// ---------- GUI ----------
~w = Window("SC typing keyboard looper", Rect(100, 100, 640, 310)).front;
~w.view.background = Color.gray(0.15);

StaticText(~w, Rect(10, 10, 620, 18))
.string_("Play: a , o . e u y i f d g h t | Panic: \\")
.stringColor_(Color.white);

~status = StaticText(~w, Rect(10, 32, 620, 18)).stringColor_(Color.gray(0.9));

~looperDisplay = StaticText(~w, Rect(10, 57, 620, 160))
.font_(Font("Menlo", 12))
.stringColor_(Color(0.65, 0.95, 0.7));

Button(~w, Rect(10, 228, 85, 26))
.states_([["PLAY", Color.white, Color(0.25, 0.4, 0.25)]])
.action_({ ~startTransport.(); ~updateLooperDisplay.() });

Button(~w, Rect(105, 228, 85, 26))
.states_([["STOP", Color.white, Color(0.6, 0.2, 0.2)]])
.action_({ ~stopTransport.(); ~updateLooperDisplay.() });

~recordButton = Button(~w, Rect(200, 228, 85, 26))
.states_([["REC", Color.white, Color.gray(0.3)], ["RECORDING", Color.white, Color.red]])
.action_({ |button|
    ~toggleRecording.();
    button.value = ~recording.binaryValue;
    ~updateLooperDisplay.();
});

Button(~w, Rect(295, 228, 85, 26))
.states_([["CLEAR TRACK", Color.white, Color(0.5, 0.2, 0.2)]])
.action_({ ~clearSelectedTrack.(); ~updateLooperDisplay.() });

~trackButtons = ~trackNames.collect { |name, trackIndex|
    Button(~w, Rect(10 + (trackIndex * 95), 275, 85, 26))
    .states_([[name.asString.toUpper, Color.white, Color.gray(0.28)]])
    .action_({
        ~selectTrack.(trackIndex);
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
    ~status.string = "typing base: % , scale: %"
    .format(~baseMidi, ~scale.name);
};

~updateLooperDisplay = {
    var degrees = ~trackDegrees[~selectedTrack].collect(_.asString).join(" ");
    var transportLine = if(~playing) {
        "| TRANSPORT: PLAYING                    |\n"
    } {
        "| TRANSPORT: STOPPED                    |\n"
    };
    var trackState = { |trackIndex|
        if(~recording and: { ~selectedTrack == trackIndex }) { "REC " } {
            if(~playing) { "PLAY" } { "STOP" };
        };
    };
    ~looperDisplay.string = "+-------------------------------------+\n"
    ++ transportLine
    ++ "+---------+-------------+--------+\n"
    ++ "| TRACK   | PDEF        | STATE  |\n"
    ++ "+---------+-------------+--------+\n"
    ++ "| 1       | \\arp1       | " ++ trackState.(0) ++ " |\n"
    ++ "| 2       | \\bass       | " ++ trackState.(1) ++ " |\n"
    ++ "| 3       | \\pad        | " ++ trackState.(2) ++ " |\n"
    ++ "| 4       | \\melody     | " ++ trackState.(3) ++ " |\n"
    ++ "+---------+-------------+--------+\n"
    ++ "| SELECTED: % BASE: % |\n".format(~selectedTrack + 1, ~trackRoots[~selectedTrack])
    ++ "| DEGREES: % |\n".format(if(degrees.isEmpty) { "(empty)" } { degrees })
    ++ "+-------------------------------------+";
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
    ~touchOscModeResponder.free;
    ~sharpResponder.free;
    ~chordsResponder.free;
    ~pushResponders.do(_.free);
	~noteParamResponders.do(_.free);
    ~cutoffResponder.free;
    ~displayRoutine.stop;
    ~stopTransport.();
    ~panic.();
});

)

// ---------- GUI ----------

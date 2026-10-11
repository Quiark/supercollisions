// Dvorak layout, middle row of the keyboard are the white keys, top rows are black keys


(
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

~sharpHeld = false;
~chordMode = 0;
~touchOscMode = \play;

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

~chordsResponder = OSCdef(\mChord, { |msg|
    if(msg[1].asFloat > 0.5) {
        ~chordMode = (~chordMode + 1) % 3;
        { ~updateLooperDisplay.() }.defer;
    };
}, '/mChord');

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

~masterReverbGamma = OSCdef(\masterReverbGamma, { |msg|
    ~masterReverbDamp = msg[1].asFloat.clip(0, 1);
    if(~masterReverb.notNil) { ~masterReverb.set(\mix, ~masterReverbDamp) };
}, '/gamma');

// ---------- GUI ----------
~w = Window("SC typing keyboard looper", Rect(100, 100, 740, 410)).front;
~w.view.background = Color.black;

StaticText(~w, Rect(10, 10, 720, 18))
.string_("Play: a , o . e u y i f d g h t | Panic: \\")
.stringColor_(Color.white);

~status = StaticText(~w, Rect(10, 32, 720, 18)).stringColor_(Color.gray(0.9));

~looperDisplay = StaticText(~w, Rect(10, 57, 720, 250))
.font_(Font("Menlo", 16))
.stringColor_(Color(0.65, 0.95, 0.7));

Button(~w, Rect(10, 325, 85, 26))
.states_([["PLAY", Color.white, Color(0.25, 0.4, 0.25)]])
.action_({ ~startTransport.(); ~updateLooperDisplay.() });

Button(~w, Rect(105, 325, 85, 26))
.states_([["STOP", Color.white, Color(0.6, 0.2, 0.2)]])
.action_({ ~stopTransport.(); ~updateLooperDisplay.() });

~recordButton = Button(~w, Rect(200, 325, 85, 26))
.states_([["REC", Color.white, Color.gray(0.3)], ["RECORDING", Color.white, Color.red]])
.action_({ |button|
    ~toggleRecording.();
    button.value = ~recording.binaryValue;
    ~updateLooperDisplay.();
});

Button(~w, Rect(295, 325, 85, 26))
.states_([["CLEAR TRACK", Color.white, Color(0.5, 0.2, 0.2)]])
.action_({ ~clearSelectedTrack.(); ~updateLooperDisplay.() });

~trackButtons = ~trackNames.collect { |name, trackIndex|
    Button(~w, Rect(10 + (trackIndex * 95), 372, 85, 26))
    .states_([[name.asString.toUpper, Color.white, Color.gray(0.28)]])
    .action_({
        ~selectTrack.(trackIndex);
        ~updateLooperDisplay.();
    });
};

~cutoffLabel = StaticText(~w, Rect(575, 325, 145, 18))
.string_("CUTOFF: -- Hz")
.stringColor_(Color(0.65, 0.95, 0.7));

~cutoffMeter = LevelIndicator(~w, Rect(575, 348, 145, 16))
.warning_(0.75)
.critical_(0.9)
.drawsPeak_(false);

~updateStatus = {
    ~status.string = "typing base: % , scale: %"
    .format(~baseMidi, ~scale.name);
};

~updateLooperDisplay = {
    var degrees = ~trackDegrees[~selectedTrack].collect(_.asString).join(" ");
    var chordMode = switch(~chordMode, 0, { "  OFF  " }, 1, { " TRIAD " }, 2, { "SEVENTH" });
    var transportLine = if(~playing) {
        "│ TRANSPORT: PLAYING             │\n"
    } {
        "│ TRANSPORT: STOPPED             │\n"
    };
    var trackState = { |trackIndex|
        if(~recording and: { ~selectedTrack == trackIndex }) { "REC   " } {
            if(~playing) { "PLAY  " } { "STOP  " };
        };
    };
    ~looperDisplay.string = "┌────────────────────────────────┐\n"
    ++ transportLine
    ++ "│ INPUT: %   CHORDS:  % │\n".format(~touchOscMode.asString.toUpper, chordMode)
    ++ "├─────────┼─────────────┼────────┤\n"
    ++ "│ TRACK   │ PDEF        │ STATE  │\n"
    ++ "├─────────┼─────────────┼────────┤\n"
    ++ "│ 1       │ \\arp1       │ " ++ trackState.(0) ++ " │\n"
    ++ "│ 2       │ \\bass       │ " ++ trackState.(1) ++ " │\n"
    ++ "│ 3       │ \\pad        │ " ++ trackState.(2) ++ " │\n"
    ++ "│ 4       │ \\melody     │ " ++ trackState.(3) ++ " │\n"
    ++ "└─────────┴─────────────┴────────┘\n"
    ++ " SELECTED: % ROOT: %             \n".format(~selectedTrack + 1, ~trackRoots[~selectedTrack])
    ++ " DEGREES: %                      \n".format(if(degrees.isEmpty) { "(empty)" } { degrees })
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
    ~masterReverbGamma.free;
    ~displayRoutine.stop;
    ~stopTransport.();
    ~panic.();
});

)

// ---------- GUI ----------

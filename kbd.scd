// Dvorak layout, middle row of the keyboard are the white keys, top rows are black keys


(
// ---------- musical settings ----------
~scale = Scale.minorPentatonic;   // try Scale.dorian, Scale.aeolian
~root  = 48;                      // MIDI note
~oct   = 1;

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

~degreeToMidi = { |deg|
    var degrees = ~scale.degrees;
    var octAdd = (deg div: degrees.size) * 12;
    ~root + (~oct * 12) + degrees.wrapAt(deg) + octAdd;
};

~noteOn = { |ch|
	var midi;
    var deg = ~keyMap[ch];
	'ch='.post;
	ch.post;
	' deg='.post;
	deg.postln;
    if(deg.isNil) { ^nil };
    if(~held[ch].notNil) { ^nil };

    midi = ~degreeToMidi.(deg);
    ~held[ch] = Synth(\ring, [
        \freq, midi.midicps,
        \amp, 0.9,
        //\bright, 1800,
        //\rq, 0.22,
        //\pan, deg.linlin(0, 12, -0.6, 0.6)
    ]);
};

~noteOff = { |ch|
    var syn = ~held[ch];
    if(syn.notNil) {
        syn.set(\gate, 0);
        ~held.removeAt(ch);
    };
};

~panic = {
    ~held.values.do { |syn| syn.set(\gate, 0) };
    ~held.clear;
    "panic: all notes off".postln;
};

~oscKeyAction = { |msg|
    var key = msg[0].asString.split($/).last.asSymbol;
    var ch = ~oscKeyMap[key];
    var value = msg[1];

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

// ---------- GUI ----------
~w = Window("SC typing keyboard (click here first)", Rect(100, 100, 560, 95)).front;
~w.view.background = Color.gray(0.15);

StaticText(~w, Rect(10, 10, 540, 18))
.string_("Play: a w s e d f t g y h u j k | Octave: [ ] | Root: - = | Panic: \\")
.stringColor_(Color.white);

~status = StaticText(~w, Rect(10, 35, 540, 18)).stringColor_(Color.gray(0.9));

~updateStatus = {
    ~status.string = "root: % , scale: %, octave: %"
    .format(~root, ~scale.name, ~oct);
};
~updateStatus.();

~w.view.keyDownAction = { |view, char, mod, unicode, keycode|
    switch(char,
        $[, { ~oct = (~oct - 1).clip(-4, 4); ~updateStatus.(); },
        $], { ~oct = (~oct + 1).clip(-4, 4); ~updateStatus.(); },
        $-, { ~root = (~root - 1).clip(0, 127); ~updateStatus.(); },
        $=, { ~root = (~root + 1).clip(0, 127); ~updateStatus.(); },
        $\\, { ~panic.(); },
		{ ~noteOn.(char); ~status.string = "char: %".format(char) }
    );
};

~w.view.keyUpAction = { |view, char, mod, unicode, keycode|
    ~noteOff.(char);
};

~w.onClose_({
    ~oscKeyResponders.do(_.free);
    ~panic.();
});

"Ready: click the window, then type a w s e d f ...".postln;
)

// ---------- GUI ----------

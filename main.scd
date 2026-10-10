(
	~projectDir = thisProcess.nowExecutingPath.dirname;
	~reverbMode = \none; // \current, \nhhall, or \none

	~reload = {
		(~projectDir +/+ "synthdefs.scd").load;
		(~projectDir +/+ "piece2.scd").load;
	};

	~reload.();
	(~projectDir +/+ "kbd.scd").load;
)


s.queryAllNodes;



(
    // frog
	~trackNoteParams[0].putAll((
		lpf: 0.28,
		lpfq: 0.18,
		detune: 0.16,
		lfodep: 0.32,
		lforate: 0.22,
		alpha: 0.12,
		beta: 0.24,
		amp: 0.28
	));
)






~kbdInstr = \stones;


(
// run this once only
thisProcess.addOSCRecvFunc({ |msg, time, replyAddr, recvPort|
	~recvFunc.(msg, time, replyAddr, recvPort);
});

)

~pushTouchOscGrid.(~sarpStepsByRow);
~pushTouchOscGrid.(~stepsByRow);

	OSCdef.trace(true);
	OSCdef.trace(false);


Pdef(\arpeggio).stop;
SCLOrkSynths.gui;
OSCdef.all.keys.postln;

Synth(\metallic_arp, [atk: 0.3, freq: 380, rel: 0.9, modIndex: 3.5, modMult: 1.231]);

Env.asr



p.stop;
(
SynthDef(\ringarp, {
    arg out = 0, freq = 440,  gate = 1,  detune = 0.0015,  fd = 5;
    var sig, ampEnv;

	var detuneFactors = [ -2, -1, 0, 1, 2] * detune + 1;

	ampEnv = EnvGen.kr(Env.perc(0.21, 0.6), gate, doneAction: 2);
	//sig = Pulse.ar(freq * detuneFactors, 0.4);
	//sig = sig + Saw.ar(freq * 2, 0.3);
	sig = Pulse.ar(freq * detuneFactors, 0.7);
	//sig = Resonz.ar(sig, freq * 4, 0.5);
	sig = LPF.ar(sig, Line.kr(freq / 4, freq * 4, 0.9));


	sig = Splay.ar(sig);
	//sig = NHHall.ar(sig);

	Out.ar(out, sig * ampEnv);
}).play;
)

(
Pdef(\arp,
	Pbind(
		\instrument, \stones,
		\scale, ~scale,
		\octave, 6,
		\degree, Pseq([0, \rest, 2, \rest, 4], inf),
		\dur, 0.25,
		\legato, 0.7,
		\amp, 0.1,
        \lpf, Pfunc { ~noteParams[\lpf] },
        \lpfq, Pfunc { ~noteParams[\lpfq] },
        \detune, Pfunc { ~noteParams[\detune] },
        \lfodep, Pfunc { ~noteParams[\lfodep] },
        \lforate, Pfunc { ~noteParams[\lforate] },
        \alpha, Pfunc { ~noteParams[\alpha] },
        \beta, Pfunc { ~noteParams[\beta] }

	)
).play(quant: ~beatsPerBar);
)




Pdef(\arp).stop;

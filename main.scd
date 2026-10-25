(
	~projectDir = thisProcess.nowExecutingPath.dirname;
	~reverbMode = \none; // \current, \nhhall, or \none
	~trackInstruments = [
		(synthDef: \stones, params: (
			lpf: 0.28, lpfq: 0.18, detune: 0.16,
			lfodep: 0.32, lforate: 0.22, alpha: 0.12, beta: 0.24, amp: 0.28
		)),
		(synthDef: \stones, params: (rls: 0.2, atk: 0.2, detune: 0.057,
		     lfodep: 0.9, lforate: 0.81, lfoshape: 0.2, lpf: 0.54, lpfq: 0.126)),
		(synthDef: \kbdAmbient, params: ()),
		(synthDef: \fmbass, params: ())
	]; // arp1, bass, pad, melody

	~reload = {
		if(~panic.notNil) { ~panic.() };
		(~projectDir +/+ "synthdefs.scd").load;
		(~projectDir +/+ "piece2.scd").load;
		(~projectDir +/+ "kbd.scd").load;
	};

	~reload.();
)


s.queryAllNodes;

~dumpPreset.();


Synth(\metallic_arp, [atk: 0.3, freq: 380, rel: 0.9, modIndex: 3.5, modMult: 1.231]);

(
SynthDef(\ringarp, {
    arg out = 0, freq = 440,  gate = 1,  detune = 0.0015;
    var sig, ampEnv;

	var detuneFactors = [ -2, -1, 0, 1, 2] * detune + 1;

	ampEnv = EnvGen.kr(Env.perc(0.21, 0.6), gate, doneAction: 2);
	sig = Pulse.ar(freq * detuneFactors, 0.7);
	sig = LPF.ar(sig, Line.kr(freq / 4, freq * 4, 0.9));


	sig = Splay.ar(sig);

	Out.ar(out, sig * ampEnv);
}).play;
)

Env.new([[0, 0], [0.1, 1], [0.3 * 2, 1], [0.8, 0]], \exp).plot;
Env.new([0, 1, 0.3, 0], times: [0.3, 0.8, 1.2], curve: 0.9).plot;

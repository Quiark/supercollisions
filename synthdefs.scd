
SynthDef(\hihat1, {arg out = 0, amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0;
	var snd = WhiteNoise.ar(amp);
	var env = Env.perc(att, rel).kr(doneAction: 2);
	snd = HPF.ar(snd * env, ffreq);
	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "Bruno Tucunduva Ruviaro",
	category: \drums,
	tags: [\percussion, \hihat]
)
).add;


SynthDef("doubleBass", {
	arg
	// Standard Values
	out = 0, pan = 0, amp = 1.0, freq = 440, att = 0.01, rel = 1.0 , crv = -30, vel = 1.0,
	// Other Controls
	freqDev = 2, op1mul = 0.1, op2mul = 0.1, op3mul = 0.1, sprd = 0.5, subAmp = 0.1;

	var env, op1, op2, op3, op4, snd, sub;

	// Percussive Envelope
	env = Env.perc(
		attackTime: att,
		releaseTime: rel,
		curve: crv
	).ar(doneAction: 2);

	// Overtones
	op1 = SinOsc.ar(
		freq: freq * 4,
		mul: vel / 2 + op1mul);

	op2 = SinOsc.ar(
		freq: freq * 3,
		phase: op1,
		mul: vel / 2 + op2mul);

	op3 = SinOsc.ar(
		freq: freq * 2,
		phase: op2,
		mul: vel / 2 + op3mul);

	// Fundamental Frequency
	op4 = SinOsc.ar(
		freq: freq + NRand(-1 * freqDev, freqDev, 3),
		phase: op3,
		mul: vel);

	// Delay Line with Multi-Channel Expansion
	snd = {
		DelayN.ar(
			in: op4,
			maxdelaytime: 0.06,
			delaytime: Rand(0.03, 0.06)
		)} !8;

	// High Pass Filter
	snd = LeakDC.ar(snd);

	// Stereo Spread
	snd = Splay.ar(
		inArray: snd,
		spread: sprd,
		level: 0.6,
		center: pan);

	// Add a sub
	sub = SinOsc.ar(
		freq: freq/2,
		mul: env * subAmp);
	sub = Pan2.ar(sub, pan);
	snd = snd + sub;

	//Ouput Stuff
	snd = snd * env;
	snd = snd * amp;
	snd = Limiter.ar(snd);
	Out.ar(out, snd);
},
metadata: (
	credit: "Matias Monteagudo",
	category: \bass,
	tags: [\pitched, \bass]
)
).add;


// ---- basic ones from gippity 5 -------
SynthDef(\kick, { |out=0, amp=0.9|
	var env = Env.perc(0.001, 0.18).ar(doneAction:2);
	var fenv = Env([80, 45], [0.03], curve: -6).ar;
	var sig = SinOsc.ar(fenv) * env;
	sig = sig + (BPF.ar(WhiteNoise.ar(0.15), 120, 0.5) * env * 0.5);
	Out.ar(out, (sig * amp).dup);
}).add;

SynthDef(\snare, { |out=0, amp=0.6|
	var env = Env.perc(0.001, 0.16).ar(doneAction:2);
	var noise = BPF.ar(WhiteNoise.ar, 1800, 0.8) * env;
	var tone = SinOsc.ar(200) * Env.perc(0.001, 0.10).ar;
	Out.ar(out, ((noise + tone) * amp).dup);
}).add;

SynthDef(\hat, { |out=0, amp=0.35|
	var env = Env.perc(0.001, 0.06).ar(doneAction:2);
	var sig = HPF.ar(WhiteNoise.ar, 7000) * env;
	Out.ar(out, (sig * amp).dup);
}).add;

// from ai but sucks
SynthDef(\metallic_arp, {
    arg out = 0, freq = 440, amp = 0.2, gate = 1, pan = 0,
        atk = 0.002, dec = 0.12, sus = 0.0, rel = 0.1,
        ffreq = 2000, rq = 0.25, 
        modIndex = 3.5, modMult = 2.71; // Non-integer multipliers sound more metallic
        
    var carrier, modulator, modEnv, ampEnv, sig;

    // Snappy amp envelope for fast arpeggios
    ampEnv = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
    
    // Quick decay envelope to make the metallic ring "pluck" at the start of the note
    modEnv = EnvGen.kr(Env.adsr(0.001, 0.06, 0.1, 0.1), gate);

    // The modulator creates the metallic frequency
    modulator = SinOsc.ar(freq * modMult) * (modIndex * modEnv * 1000);

    // PMOsc introduces phase modulation (FM synthesis) using the modulator
    carrier = PMOsc.ar(freq, freq * modMult, modIndex * modEnv);
    
    // Mix the FM carrier with a detuned Saw for extra electronic body
    sig = Mix.new([carrier * 0.7, Saw.ar(freq * 1.005) * 0.3]);

    // Resonant low pass filter to shape the high-end ring
    sig = RLPF.ar(sig, ffreq, rq);

    // Apply envelope and output in stereo
    sig = Pan2.ar(sig * ampEnv * amp, pan);
    Out.ar(out, sig);
}).gui;


// ---- mine -------
// arp inspired by KVNDRA
SynthDef(\tonea, { |out=0, amp=0.75, freq=440|
	var env = Env.perc(0.08, 0.26).ar(doneAction:2);
	var sig = HPF.ar(Saw.ar(freq), 7000) * env;
	Out.ar(out, (sig * amp).dup);
}).add;

SynthDef(\pupluck, {
    arg out = 0, freq = 110,  gate = 1,  detune = 0.003,  fd = 5;
    var sig, ampEnv;

	var detuneFactors = [ -2, -1, 0, 1 ,2] * detune + 1;

	ampEnv = EnvGen.kr(Env.perc(0.01, 1.0, 1), gate, doneAction: 2);
	sig = Pulse.ar(freq * detuneFactors, 0.4);
	//sig = sig + Saw.ar(freq * 2, 0.3);
	sig = sig + SinOsc.ar(freq / 2, 0.3);
	// sig = Ringz.ar(sig, freq * 4, MouseY.kr(0, 1));
	sig = LPF.ar(sig, (freq * fd).poll);


	sig = Splay.ar(sig);
//	sig = NHHall.ar(sig);

	Out.ar(out, sig * ampEnv);
}).play;

// :...
// ---------- ---------- NOTES ---------- ----------
/*
- all synths run all the time so we can realtime change their params but that also means fixed number of synths, how we gonna play chords or more keys?

- instruments i want
- higher pitch resonating something, like beginning of "In Stars we drown"
*/


// :...
// ---------- ---------- INSTRUMENTS ---------- ----------

(
// from LossOfSelf

SynthDef.new(\als, { // This synth definition has a bunch of stuff in it that makes this sound the way it does. It's the instrument.
	arg freq = 440,
	atk = 0.005, rel = 0.3, amp = 1,
	pan = 0, gain = 1,
	modIndex = 2, phaseModIndex = 2,
	lpfFreq = 18000, resonance = 0,
	hold = 6.0,
	freqDeviation = 0.975,
	transitionTime = 0.875,
	resonzQ = 0.1,
	gate = 0;

	var sig, mod, phasemod, env;
	freq = freq.clip(20, 20000); // .clip because better safe than sorry. SC can get superLoud otherwise.
	mod = SinOsc.ar(freq/2, 0, Line.ar(0, modIndex, transitionTime) * freq); // Frequency Modulation.
	phasemod = SinOsc.ar(freq, 0, phaseModIndex); // Phase Modulation.
	sig = SinOsc.ar(XLine.ar(freqDeviation, freq, atk) + mod, phasemod); // Glissando.
	env = EnvGen.kr(Env.new([0, 1, 1, 0], [atk, hold, rel], \sine), gate); // Envelope.
	sig = Pan2.ar(sig, Line.ar(0,pan, transitionTime), amp); // Panning.
	sig = (sig * 0.8) + (Pluck.ar(sig, PinkNoise.ar(), 0.25, freq.reciprocal, 64.0, 0.5) * 0.4); // Mixer.
	sig = RLPF.ar(sig, lpfFreq.clip(200, 20000), (Line.ar(1.0,resonance, resonance, atk)).clip(0.1, 1.0) ) * env; // Resonant Low Pass Filter.
	sig = tanh(Line.ar(0.001, gain, transitionTime) * sig); // A kind of distortion.
	sig = (sig * 0.75) + (Resonz.ar(sig, freq, resonzQ) * 1.125); // A kind of ringing filter.
	sig = sig * AmpCompA.kr(freq,12.978271799373); // AmpComp does a kind of compensation that follows your hearing. It's good.
	sig = Compander.ar(sig,sig,0.25, 0.33, 1, 0.002, 0.1); // Compressor.
	sig = LeakDC.ar(sig) ; // This protects against DC offset.
	sig = HPF.ar( sig, 32 ); // This is a high pass filter.

	Out.ar(0, Limiter.ar(sig,0.1)); // Limiter.
	}
).add;

SynthDef.new(\droneFM, {
	arg f1Freq=0.1, f2Freq=1.1, f3Freq=2.2,
	nFreq=440,
	m1Ratio=1, m2Ratio=2, m3Ratio=3,
	amp=0.6, dur=55, ampM=0.84 , pan=0, gate=0;
	var sig, car1, mod1, car2, mod2, car3, mod3, env, index;
	index = LFNoise1.kr(0.2).range(2, 12);
	env = EnvGen.kr(Env.new([0, 0.70, 0.70, 0], [dur*0.333, dur*0.333, dur*0.333]), gate);
	mod1 = SinOsc.ar([nFreq * m1Ratio, nFreq+0.7 * m1Ratio], mul:nFreq * m1Ratio * index) * ampM;
	car1 = SinOsc.ar(f1Freq + mod1);
	mod2 = SinOsc.ar([nFreq * m2Ratio, nFreq+1.4 * m2Ratio], mul:nFreq * m2Ratio * index) * ampM;
	car2 = SinOsc.ar(f2Freq + mod2);
	mod3 = SinOsc.ar([nFreq * m3Ratio, nFreq+0.35 * m3Ratio], mul:nFreq * m3Ratio * index) * ampM;
	car3 = SinOsc.ar(f3Freq + mod3) * 0.4;
	sig = (car1 + car2 + car3) * env * amp;
	sig = Pan2.ar(sig, pan).flat;
	Out.ar(0, sig)
}).add;

SynthDef.new(\simple, {
	arg gate = 0, freq = 400, amp = 0.5;
	var sig = SinOsc.ar(freq * [1, 1], 0);
	var env = EnvGen.ar(Env.asr(0.1, amp, 1.3), gate, doneAction: 2).poll;
	Out.ar(0, sig * env)
}).add;

SynthDef.new(\pulse, {
	arg gate = 0, freq = 440, amp = 0.2;
	var sig = Pulse.ar(440 * [0.5, 0.752], LFNoise1.kr(0.3).range(0.3, 0.7));
	var env = EnvGen.ar(Env.asr(0.1, amp, 0.3), gate, doneAction: 2);
	Out.ar(0, sig * env)
}).add;

// :...
// ---------- ---------- STATE ---------- ----------

/*
~voiceA = Synth(\als);
~voiceA.set(\gate, 0);

~voiceB = Synth(\droneFM);
~voiceB.set(\gate, 0);

~voiceC = Synth(\simple);
~voiceC.set(\gate, 0);
*/

~curVoice = "c";
~notes = "CDEFGAB";
~state = (
	vibrato: 0.0,
	playing: Dictionary.new(7)
);

~notes.do { |it|
	"abc".do { |v|
		~state.playing.put(it.asString + v.asString, (
			voice: nil,
		));
	}
};


// :...
// ---------- ---------- CONTROL ---------- ----------
(
~getVoice = {
	var voices = Dictionary.newFrom(["a", ~voiceA, "b", ~voiceB, "c", ~voiceC]);
	voices[~curVoice]
};

~getInstrument = {
	var choices = Dictionary.newFrom(["a", \als, "b", \pulse, "c", \simple]);
	choices[~curVoice]
};

OSCdef.new(
	\voiceA,
	{ arg msg, time, addr, port;
		[msg, time, addr, port].postln;
		~curVoice = "a";
	},
	'/voices/a'
);
OSCdef.new(
	\voiceB,
	{ arg msg, time, addr, port;
		[msg, time, addr, port].postln;
		~curVoice = "b";
	},
	'/voices/b'
);
OSCdef.new(
	\voiceC,
	{ arg msg, time, addr, port;
		[msg, time, addr, port].postln;
		~curVoice = "c";
	},
	'/voices/c'
);

OSCdef.new(
	\vibrato,
	{ arg msg, time, addr, port;
		[msg, time, addr, port].postln;
		~state.vibrato = msg[1];
	},
	'/vibrato'
);

~notes.do { |it|
	OSCdef.new(
		("note" ++ it).asSymbol,
		{ arg msg, time, addr, port;
			var on = msg[1], k = it.asString + ~curVoice, v;

			var instr = (~getInstrument).(),
			noteStep = Dictionary.newFrom(["C", 0, "D", 2, "E", 4, "F", 5, "G", 7, "A", 9, "B", 11]);

			v = (~state.playing)[k].voice;
			if(v != nil, {
				// v.free();
				v.set(\gate, 0);
				// (~state.playing)[k].voice = nil;
			}, {});

			if(on == 1.0, {
				v = Synth(instr, [\freq, (60 + noteStep[it.asString]).midicps, \gate, on]);
				(~state.playing)[k].voice = v;
			},{

			});

			[msg, time, addr, port, k, v].postln;

		},
		'/keys/'++it
	);
};
)
)
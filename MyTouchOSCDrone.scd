// :...
// ---------- ---------- NOTES ---------- ----------
/*
- all synths run all the time so we can realtime change their params but that also means fixed number of synths, how we gonna play chords or more keys?

- instruments i want
- higher pitch resonating something, like beginning of "In Stars we drown"

- TODO weird that it has 2 mixers on start, am i doing something wrong with groups?
*/


// :...
// ---------- ---------- INSTRUMENTS ---------- ----------

s.reboot;





s.waitForBoot({
    //s.notify = true;
    //NodeWatcher.register(s);


SynthDef.new(\simple, {
	arg gate = 0, freq = 400, amp = 1, out, vibr = 0, reverb = 0;
	var env;
	var sig = SinOsc.ar(freq * [1, 1] + vibr, 0);
	sig = FreeVerb2.ar(sig[0], sig[1], mix: reverb, room: 0.8, damp: 0.5);
	env = EnvGen.ar(Env.asr(0.03, amp * 0.8, 1.3), gate, doneAction: 2);
	Out.ar(out, sig * env)
}).add;

SynthDef.new(\pulse, {
	arg gate = 0, freq = 440, amp = 1, out, vibr = 0, reverb = 0;
	var env;
	var sig = Pulse.ar(freq * [0.5, 0.752] + vibr, LFNoise1.kr(0.3).range(0.3, 0.7));
	sig = FreeVerb2.ar(sig[0], sig[1], mix: reverb, room: 0.8, damp: 0.5);
	env = EnvGen.ar(Env.asr(0.03, amp, 0.3), gate, doneAction: 2);
	Out.ar(out, sig * env)
}).add;

SynthDef.new(\saw, {
	arg gate = 0, freq = 400, amp = 1, out, vibr = 0, reverb = 0;
	var env;
	var sig = VarSaw.ar(freq * [1, 1] + vibr);
	sig = FreeVerb2.ar(sig[0], sig[1], mix: reverb, room: 0.8, damp: 0.5);
	env = EnvGen.ar(Env.asr(0.03, amp * 0.5, 1.3), gate, doneAction: 2);
	Out.ar(out, sig * env)
}).add;


// :...
// ---------- ---------- STATE ---------- ----------


~curVoice = "c";
~notes = "CDEFGAB";
~mixN = 7*4;
~state = (
	vibrato: 0.0,
	playing: Dictionary.new(7),
	bus: Bus.audio(s, ~mixN),
);
~state.bus.scope;

~fn = (

	getInstrument: {
		var choices = Dictionary.newFrom(["a", \saw, "b", \pulse, "c", \simple, "d", \simple]);
		choices[~curVoice]
	},

	applyAll: { | th, pr = 'vidle', value = 0.3 |
		":: Applying % = % to all voices".format(pr, value).postln;
		~state.playing.keysValuesDo { |k, it|
			if(it.voice != nil, {
					it.voice.set(pr, value);
			}, {});
		};

	},
);

~notes.do { |it|
	"abcd".do { |v|
		~state.playing.put(it.asString + v.asString, (
			voice: nil,
		));
	}
};

~srcG = Group.head(s);
~mixG = Group.after(~srcG);

SynthDef(\mixer, { |inbus, n=12, spread=1.0, level=1.0, center=0.0|
    var sigs = In.ar(inbus, ~mixN); // reads an array [n channels]
    var out  = Splay.ar(sigs, spread, level, center, levelComp: true);
    // Optional safety
    //out = Limiter.ar(out, 0.98, 0.01);
	Out.ar(0, out);
}).add;


s.sync;
Synth(\mixer, [\inbus, ~state.bus, \n, ~mixN], ~mixG);

//Synth(\simple, [\freq, 440, \out, ~state.bus.index + 0], ~srcG);

// :...
// ---------- ---------- CONTROL ---------- ----------
(

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
	\voiceD,
	{ arg msg, time, addr, port;
		[msg, time, addr, port].postln;
		~curVoice = "d";
	},
	'/voices/d'
);

OSCdef.new(
	\vibrato,
	{ arg msg, time, addr, port;
		var val = (msg[1] - 0.5) * 60.0;
		[msg, time, addr, port].postln;

		~state.vibrato = val;
		~fn.applyAll(\vibr, val);
	},
	'/vibrato'
);

OSCdef.new(
	\reverb,
	{ arg msg, time, addr, port;
		var val = msg[1];
		[msg, time, addr, port].postln;

		~fn.applyAll(\reverb, val);
	},
	'/knobs/reverb'
);

OSCdef.new(
	\xy,
	{ arg msg, time, addr, port;
		var val = (msg[1] - 0.5) * 500;
		var amp = (msg[2]);
		[msg, time, addr, port].postln;
		~state.vibrato = val;
		~fn.applyAll(\vibr, val);
		~fn.applyAll(\amp, amp);
	},
	\xy1
);

~notes.do { |it|
	OSCdef.new(
		("note" ++ it).asSymbol,
		{ arg msg, time, addr, port;
			var on = msg[1], k = it.asString + ~curVoice, v;

			var instr = (~fn.getInstrument).();
			var nix = ~notes.indexOf(it);
			var vix = if(~curVoice=="a", 0, if(~curVoice=="b", 1, if(~curVoice=="c", 2, 3)));

			var noteStep = Dictionary.newFrom(["C", 0, "D", 2, "E", 4, "F", 5, "G", 7, "A", 9, "B", 11]);
					[vix, nix, ~curVoice, nix + (vix*7)].postln;
			v = (~state.playing)[k].voice;
			if(v != nil, {
				// v.free();
				v.set(\gate, 0);
				// (~state.playing)[k].voice = nil;
			}, {});

			if(on == 1.0, {
				v = Synth(instr, [\freq, (60 + noteStep[it.asString]).midicps,
					\gate, on,
					\out, nix + (vix*7),
				], ~srcG);
				//v.onFree({ (~state.playing)[k].voice = nil; });
				(~state.playing)[k].voice = v;
			},{

			});

			[msg, time, addr, port, k, v].postln;

		},
		'/keys/'++it
	);
};
)


});

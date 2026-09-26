// TODO: more ideas
//  - use buttons in PARAMS to switch different note patterns for the ARP
//  + can we have a global key to reload everything?
//  - I guess we always need reverb
//  - KVDRA's arpeggio has params changing over time
~arpTranspose = 0;
~arpEnable = true;
~rotary1 = 0;
~rotary2 = 0;
~rotary3 = 0;
~rotary4 = 0;
~rotary5 = 0;
~rotary6 = 0;


/*
SynthDef(\masterReverb, { |out=0, mix=0.28, room=0.88, damp=0.45, amp=1|
	var dry, wet;

	dry = In.ar(out, 2);
	wet = FreeVerb2.ar(dry[0], dry[1], mix: mix, room: room, damp: damp);
	ReplaceOut.ar(out, LeakDC.ar(wet) * amp);
}).add;

~masterReverb = Synth.tail(s, \masterReverb);
*/

// originally:
//\instrument, \sarp,
//\degree, Pseq([0, 2, 4, 7,], inf),
//
// currently random transposes so that i can comfortably tune the arp instrument
Pdef(\arpeggio, Pbind(
    \instrument, \sarp,
    \degree, Pseq([0, 2, 4], inf),  // just 3 notes, similar to KVNDRA's arpeggio
	\detune, Pfunc { ~rotary1.linlin(0, 1, 0.0001, 0.02) },
	\fd, Pfunc { ~rotary2.linlin(0, 1, 0.5, 1.8) },
    \scale, Scale.minor,
    \octave, 6,
	\ctranspose, Pstutter(3, Prand((-8..8), inf)), // TODO re-enable for live control Pfunc { ~arpTranspose },
	\amp, 0.5,
    \dur, 0.425, // Fast 16th notes
    \legato, 0.6,
	\type, Pfunc { |x| (~arpEnable).if(\note, \rest) }
)).play;

// yellow on first screen
OSCdef(\faderTranspose, { |msg|
    var rawVal = msg[1]; // The raw value coming from fader (0 to 100)
    
    // Map 0 - 100 down to -12 to +12 semitones (1 full octave down to 1 octave up)
    // Round to whole semitones so it stays in key
    var semitones = rawVal.linlin(0, 1, -12, 12).round;
    
    ~arpTranspose = semitones;
    
    // Optional: Print to post window so you can see current semitone shift
    ("Transposed to: " ++ semitones ++ " semitones " ++ rawVal).postln;
    
}, '/1/fader1'); // Listening for path '/1/fader1'

OSCdef(\arpEnable, { |msg|
	var rawVal = msg[1];
	~arpEnable = (rawVal > 0.5);
	("Arpeggio Enabled: " ++ ~arpEnable).postln;
	
}, '/1/toggle1'); // Listening for path '/1/fader2'

OSCdef(\rotary1, { |msg|
	~rotary1 = msg[1].asFloat;
}, '/3/rotary1');

OSCdef(\rotary2, { |msg|
	~rotary2 = msg[1].asFloat;
}, '/3/rotary2');

OSCdef(\rotary3, { |msg|
	~rotary3 = msg[1].asFloat;
}, '/3/rotary3');

OSCdef(\rotary4, { |msg|
	~rotary4 = msg[1].asFloat;
}, '/3/rotary4');

OSCdef(\rotary5, { |msg|
	~rotary5 = msg[1].asFloat;
}, '/3/rotary5');

OSCdef(\rotary6, { |msg|
	~rotary6 = msg[1].asFloat;
}, '/3/rotary6');

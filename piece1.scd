// originally:
//\instrument, \sarp,
//\degree, Pseq([0, 2, 4, 7,], inf),

~arpTranspose = 0;
~arpEnable = true;
~rotary1 = 0;
~rotary2 = 0;
~rotary3 = 0;
~rotary4 = 0;
~rotary5 = 0;
~rotary6 = 0;

Pdef(\arpeggio, Pbind(
    \instrument, \sarp,
    \degree, Pseq([0, 2, 4, 7,], inf),
    \scale, Scale.minor,
    \octave, 6,
	\ctranspose, Pfunc { ~arpTranspose },
	\amp, 0.3,
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
	("rotary1: " ++ ~rotary1).postln;
}, '/3/rotary1');

OSCdef(\rotary2, { |msg|
	~rotary2 = msg[1].asFloat;
	("rotary2: " ++ ~rotary2).postln;
}, '/3/rotary2');

OSCdef(\rotary3, { |msg|
	~rotary3 = msg[1].asFloat;
	("rotary3: " ++ ~rotary3).postln;
}, '/3/rotary3');

OSCdef(\rotary4, { |msg|
	~rotary4 = msg[1].asFloat;
	("rotary4: " ++ ~rotary4).postln;
}, '/3/rotary4');

OSCdef(\rotary5, { |msg|
	~rotary5 = msg[1].asFloat;
	("rotary5: " ++ ~rotary5).postln;
}, '/3/rotary5');

OSCdef(\rotary6, { |msg|
	~rotary6 = msg[1].asFloat;
	("rotary6: " ++ ~rotary6).postln;
}, '/3/rotary6');

(
// ---------- musical settings ----------
~scale = Scale.major;
~baseMidi = 48;
~kbdInstr = \stones;

SynthDef(\kbdAmbient, { |out=0, freq=440, gate=1, amp=0.15, bright=2000, rq=0.25, pan=0|
    var sig, env, cutoff;

    sig = (VarSaw.ar(freq * [1, 1.003], 0, 0.3, 0.12).sum)
        + (SinOsc.ar(freq * 0.5, 0, 0.06));
    env = EnvGen.kr(Env.asr(0.5, 1, 3.5, curve: -4), gate, doneAction: 2);
    cutoff = (bright * (0.7 + SinOsc.kr(0.08).range(0, 0.6))).clip(60, 12000);
    sig = RLPF.ar(sig, cutoff, rq);
    sig = Pan2.ar((sig * env * amp), pan);
    sig = sig + FreeVerb2.ar(sig[0], sig[1], mix: 0.25, room: 0.9, damp: 0.5);
    sig = HPF.ar(LeakDC.ar(sig), 20).tanh;
    Out.ar(out, sig);
}).add;

TempoClock.default.tempo = 120/60; // 120 bpm
~held = IdentityDictionary.new;
~heldDegrees = IdentityDictionary.new;
~heldSharpCapable = IdentityDictionary.new;
~heldChords = IdentityDictionary.new;
~sharpHeld = false;
~chordMode = 0;
~trackNames = [\arp1, \bass, \pad, \melody];
~trackDegrees = Array.fill(~trackNames.size, { List.new });
~trackIndices = Array.fill(~trackNames.size, 0);
~trackRoots = Array.fill(~trackNames.size, { ~baseMidi });
~arpDegrees = ~trackDegrees[0];
~selectedTrack = 0;
~recording = false;
~playing = false;
if(~trackPlayers.notNil) { ~trackPlayers.values.do(_.stop) };
~trackPlayers = IdentityDictionary.new;
~trackNoteParams = Array.fill(~trackNames.size, {
    (lpf: 0.0, lpfq: 0, detune: 0.0, lfodep: 0.0, lforate: 0.0, alpha: 0, beta: 0, amp: 0.83)
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

~toggleRecording = { ~recording = ~recording.not };

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
        ~trackNames.do { |name, trackIndex|
            var stonesParams = ~trackNoteParams[trackIndex].copy;
            stonesParams.putAll((instrument: ~kbdInstr, dur: 1/4, legato: 0.75, rls: 0.3));
            "% stones params: %".format(name, stonesParams).postln;
            ~trackPlayers[name] = Pdef(name).play();
        };
        ~playing = true;
    };
};

~stopTransport = {
    ~trackPlayers.values.do(_.stop);
    ~trackPlayers.clear;
    ~playing = false;
};

if(~masterReverbDamp.isNil) { ~masterReverbDamp = 0.45 };
if(~masterReverb.notNil) { ~masterReverb.free };
~masterReverb = nil;
SynthDef(\masterReverb, { |out=0, mix=0.28, room=0.88, damp=0.45, amp=1|
    var input, signal, hall;
    input = In.ar(out, 2);
    signal = switch(~reverbMode,
        \nhhall, {
            hall = NHHall.ar(
                input,
                rt60: room.linlin(0, 1, 0.1, 12),
                hiFreq: damp.linlin(0, 1, 12000, 500),
                hiRatio: damp.linlin(0, 1, 1, 0.2)
            );
            XFade2.ar(input, hall, mix.linlin(0, 1, -1, 1));
        },
        \none, { input },
        { FreeVerb2.ar(input[0], input[1], mix, room, damp) }
    );
    ReplaceOut.ar(out, LeakDC.ar(signal) * amp);
}).add;
Routine({
    s.sync;
    ~masterReverb = Synth.tail(s, \masterReverb, [\damp, ~masterReverbDamp]);
}).play(AppClock);
)

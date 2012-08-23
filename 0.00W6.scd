
(

///////////////////// TO DO
//	- fade in all'inizio (fabio)
//	- non deve modulare in mezzo al tema oppure mettiamo i gradi nell'array del tema (fabio)
//	- gestione modulazione su proxVeryHigh (raul)
//	- variazione degli accompagnamenti (raul)

//	- questo e'il tema
//	- l'armonia deve avere dei punti di contatto (4+4) , chiusura melodica cmq dopo 4
//	- due battute che si ripetono ogni tanto
//	- la 4 battuta deve essere IV o V grado (per ora no)
//	- V grado in battuta 7 e I grado in battuta 8
//	- il tema dura 8 (8 diverse o 4+4) o 4, ultima accordo sulla tonica
//	- intro evenutale di 2 o 4 battute (anche solo una mano), da farsi come oggetto
//	- primo accordo: I, IV o V
//	- metrica del pezzo
//	- dopo il tema, moduliamo o meno, ogni tanto torna il tema, se torna e sono in tonica lo rifa uguale, se lo rifa e non sono in tonica, fa il tema trasposto
//	- definire meglio il minore
//	- aggiungere qualche accordo alterato
//	- pitch fastidioso ok

///////////////////// MODULAZIONI
//	- per cromatismo o per accordo comune
//	- V grado: 	a un certo punto quando capita l'accordo di I, V, VI, posso triggerare la modulazione al V grado e shifto
//				il primo accordo sara'il V della nuova scala, poi il primo e poi via seguendo
//				dopo 4, 6, 8 battute chiamo V-reverse = IV
//	- IV grado:	ho gia'la sensibile, capita un primo grado, decido di andare al IV, shifto e vado al primo, cui segue quarto (.75) o secondo (.25) e via dicendo
//				dopo 4, 6, 8 battute chiamo IV-reverse (o bis) = V
//	- IV grado bis: capita il 2grado vecchio (VI nuovo), shifto in scala ma non restto il counter, vado sul quarto
//	- IV, V grado poi si ritorna

///////////////////// MODULAZIONE (min/maj)
//	- I algorithm,	arrivo al IV-V grado e mi piazzo al I minore della stessa tonalita' (e viceversa) non e'di passaggio
//	- II algorithm,	al relativo VI grado, stesse note ma inserisco una sensibile (3 grado del vecchio), 
//					quando ci capita un secondo shifta, va al V del nuovo, si resetta il counter e va al primo del nuovo e il tema si rifara'subito cambiato di modo
//					torniamo indietro quando capita il primo, si shifa e si va al secondo della nuova, che va al V, reset counter e si va al primo

var accompanimentTask, melody1Task, melody2Task;
var pitchStream, rhythmStream, accompanimentStream;
var pitchPattern, rhythmPattern, currentChord, currentRhythmSet;
var rhythmSetCounter, beatCounter, currentCounter, chordNotes, melodyDirection;
var mode, accompaniment, patterns, length, lengthTerz, nuAccompaniment, grades, gradesMaj, gradesHMin, harmony, harmonyHMin, harmonyMaj, startingLength, startingTone, currentTone;
var mod5, mod4, nextChord;
var themeRhythm, themePitch, themeChord, themeFlag, themeCounter, themeChordArray, themePitchArray, themeRhythmArray, themeLength, themeActive;
var o1, o2, o3, o4, o5, o6, o7, range, varDissonance, lengthDissonance, boolDissonance, counterDissonance;
var proxVeryHigh, proxHigh, proxMed, proxLow;
var soloLine, harmonicProgression, lengthAdjustment, quarti,delay, absolutePitch;

var proximity, heart, skin, other, smooth, proxMod;
var volRangeSolo, volRangeAcc;
var randomNote, dissonanceControl; //variabili per proximity;

MIDIClient.init(0,1,2); // initialize the MIDI client:	
m = MIDIOut(0, MIDIClient.destinations.at(0).uid); // create a MIDI out connection:
m.connect(1);// and connect SC's first port to your device's port with for example QJackCtl


/////////////////////  OSC connections

o1 = OSCresponderNode(nil, "/processing", {
	|t, r, mesg|
	var tmp = mesg[1];
	//tmp.postln;
	proximity = ((-1*tmp)+200)/225;
	if(proximity<0,{proximity=0},{});
	if(proximity>225,{proximity=1},{});
	"proximity: ".postln;
	proximity.postln;
	heart = (proximity/3)+0.5;
	skin = (proximity/4)+0.4;
}).add;

o3 = OSCresponderNode(nil, "/prox", {
	|t, r, mesg|
	proximity = mesg[1];
}).add;
o4 = OSCresponderNode(nil, "/heart", {
	|t, r, mesg|
	heart = mesg[1]; //work on the difference between the 2 guys
}).add;
o5 = OSCresponderNode(nil, "/skin", {
	|t, r, mesg|
	skin = mesg[1];
}).add;
o6 = OSCresponderNode(nil, "/smooth", {
	|t, r, mesg|
	smooth = mesg[1];
}).add;
o7 = OSCresponderNode(nil, "/other", {
	|t, r, mesg|
	other = mesg[1];
}).add;

/////////////////////  getting values

heart = 0.5;		// tace finche'non entrano i soggetti 
proximity = 0.5;	// dissonanza, modo, ottava
skin = 0.5;

// fino a 0.7 maggiore
// 0.4 - 0.7 minore
// 0/0.1 - 0.1/0.2 - 0.2/0.4 dissonanze


///////////////////// Mode | BPM
mode = "Maj"; // Maj
~tempo = 160*skin;
melodyDirection = true; // false -> basso
quarti = 0; // quarti=0, funereo=1, triste=2, medio=3 

"".postln;
"".postln;
"".postln;
startingTone = ['A', 'B','C','C#','D','Eb','E','F','Gb','G','Ab'].choose.postln;
range = 0; // pitch range e'8 o 0
varDissonance = 0; // da 0 a 4
// themeLength = (rrand(0,1)+1)*4; // 4 o 8
themeLength = 4;
"Lunghezza tema: ".post;
themeLength.postln;
themeCounter = themeLength;


///////////////////// mapping grades to MIDI values
~notes = ['B', 'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
gradesMaj = [-1,0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31];
gradesHMin = [-1,0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31];


// probaility matrix of harmonic progression (from Piston W., Harmony, p.17)
~accMatrix =  [[0, 0.05, 0.07, 0.35, 0.35, 0.08, 0.1],
			[0.05, 0, 0.05, 0.05, 0.65, 0.20, 0],
			[0, 0.07, 0, 0.21, 0.07, 0.65, 0],
			[0.15, 0.15, 0.05, 0, 0.60, 0.05, 0],
			[0.64, 0.05, 0.05, 0.13, 0, 0.13, 0],
			[0.06, 0.35, 0.12, 0.12, 0.35, 0, 0],
			[1, 0, 0, 0, 0, 0, 0]];


harmonyMaj=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];
harmonyHMin=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];

case{mode == "HMin"}{harmony = harmonyHMin;grades = gradesHMin}
	{mode == "Maj"}{harmony = harmonyMaj;grades = gradesMaj};


///////////////////// patterns of length definition 
//	0-3 sono potenziali inizi - OK
//	0 va in liberta', piu'zeri ci sono piu'e facile che ci rimanga - SI
//	4 va + probabilmente su se stessa e con = prob su 2 e 3, se compare piu'volte aumenta la probabilita'che rimanga li  - NO
//	2, 3 vanno con la stessa prob uno sull'altro o sul 4 - OK
//	ogni 4 si va al finale - OK
//	5, 6 finali: 5 se si e'stati tanto in 1, 6 se si e'stati tanto negli altri - OK (circa)


rhythmSetCounter = [0,0,0,0,0,0,0];	// conteggio quante volte abbiamo pescato dai vari insiemi di lunghezze

length = [
		[[2, 1, 1], [2, 1, 0.5, 0.5], [2, 0.5, 1, 0.5], [2, 0.5, 0.5, 1], [2, 0.5, 0.5, 0.5, 0.5], [4], [3, 0.5, 0.5], [3, 1], [1,1,2]], // inzio in liberta'

		[[1, 1, 1, 0.5, 0.5], [1, 1, 0.5, 1, 0.5], [1, 1, 0.5, 0.5, 1], [1, 1, 0.5, 0.5, 0.5, 0.5]], // primi due: quarti
		[[0.5, 0.5, 0.5, 0.5, 1, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5, 0.5, 1, 0.5], [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1], [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]], // primi due: ottavi		
		[[1.5, 0.5, 1, 1], [1.5, 0.5, 1, 0.5, 0.5], [1.5, 0.5, 0.5, 1, 0.5], [1.5, 0.5, 0.5, 0.5, 1], [1.5, 0.5, 0.5, 0.5, 0.5, 0.5], [1.5, 0.5, 1.5, 0.5], [1.5, 0.5, 0.5, 1, 0.5]], // puntati 1.5-0.5 
		[[0.5, 1, 0.5,1, 1], [0.5, 1, 0.5,1, 0.5, 0.5], [0.5, 1, 0.5,0.5, 1, 0.5], [0.5, 1, 0.5,0.5, 0.5, 1], [0.5, 1, 0.5,0.5, 0.5, 0.5, 0.5], [0.5, 1, 0.5,1.5, 0.5], [0.5, 1, 0.5,0.5, 1, 0.5], [1, 1, 0.5, 1, 0.5],[0.5, 0.5, 0.5, 0.5, 0.5, 1, 0.5]], // sincope
					
		[[4],[2,2],[1,1,2]], // finale a
		[[1,0.5,0.5,2],[0.5,1,0.5,2],[0.5,0.5,0.5,0.5,2],[1,1,2]] // finale b
		];

lengthDissonance = [
	[[2, 0.3, 0.7, 1], [1, 1.1, 1.9, 0.5, 0.5], [2,2], [0.2, 0.8, 0.8, 1, 0.2, 0.7, 0.3], [1,1,1,1], [1, 1, 0.5, 0.4, 1.1], [1.5, 0.7, 0.3, 0.5, 0.3, 0.7]],
	[[0.8, 0.2, 0.3, 0.7, 0.6, 1.4], [4], [1, 0.8, 3, 0.2], [0.5, 1, 0.3, 1.7, 0.5], [0.5, 1.4, 0.6, 0.5, 0.7, 0.3], [0.6, 1.4, 0.8, 1.2], [0.5, 0.8, 0.7, 1.2, 0.5, 0.3]],
	[[0.3, 0.4, 1.2, 0.6, 0.8, 0.7], [4], [0.3, 3.7], [2.8, 1.2], [0.8, 0.3, 2, 0.7, 0.2], [2,1,1], [0.3, 1.8, 0.3, 0.2, 0.7, 0.7], [0.4, 3.1, 0.5], [1,1,1.5,0.5], [0.2, 0.3, 0.8, 0.5, 0.7, 0.5, 0.2, 0.8]]
	];
	
	
// matrice dinamica, dove si definiscono le probabilita' per i 7 insiemi di pattern ritmici
~lengthProbabilityMatrix = [
						[1/5, 1/5, 1/5, 1/5, 1/5, 0, 0],
						[1/5, 1/5, 1/5, 1/5, 1/5, 0, 0],
						[0.04, 0.1, 0.33, 0.20, 0.33, 0, 0],
						[0.05, 0.2, 0.2, 0.35, 0.2, 0, 0],
						[0.05, 0.2, 0.2, 0.2, 0.35, 0, 0],
						[0.5, 0.3, 0.1, 0.1, 0, 0, 0],
						[0.05, 0.25, 0.35, 0.35, 0, 0, 0]
						];

///////////////////// function definition for soloLine
soloLine = { |x|
	
	//	scelta del pattern ritmico
	case{beatCounter == 1}{rhythmPattern=startingLength;}
		{beatCounter%4==0}{
			//	5, 6 finali: 5 se si e'stati tanto in 1, 6 se si e'stati tanto negli altri
			var tmp = [0,0,0,0,0,rhythmSetCounter[1],(rhythmSetCounter[2]+rhythmSetCounter[3]+rhythmSetCounter[4])/3];
			currentRhythmSet = tmp.maxIndex;
			rhythmPattern = length[currentRhythmSet].choose;
			}
		{(beatCounter!=1).and(beatCounter%4!=0)}{
			currentRhythmSet = [0,1,2,3,4,5,6].wchoose(~lengthProbabilityMatrix[currentRhythmSet]);
			rhythmPattern = length.wchoose(~lengthProbabilityMatrix[currentRhythmSet]).choose;
					};		

	// dissono un po'	
	if(rrand(4,12) <= randomNote,{
		var tmp = floor(randomNote/3.1)-1; // 0, 1 o 2
		chordNotes[0] = (1 + rrand(1,(randomNote-1)))%12;
		chordNotes[0] = (3 + rrand(1,(randomNote-1)))%12;
		chordNotes[0] = (5 + rrand(1,(randomNote-1)))%12;
		rhythmPattern =  lengthDissonance[tmp].choose;
		},{}
	);		
	
	//	scelta delle note, pitch numera da 0 a 14
	pitchPattern = [];	
	for (0, (rhythmPattern.size-1), {arg i;pitchPattern= pitchPattern ++ '***';});
	pitchPattern[rrand(0,rhythmPattern.size-1)] = [chordNotes[rrand(0,2)], range+chordNotes[rrand(0,2)]].choose; // a caso in mezzo metto una nota dell'accordo

	pitchPattern[0]=chordNotes[rrand(0,2)];  //primo della battuta: uno dei gradi dell'accordo
	pitchPattern[rhythmPattern.size-1]=chordNotes[rrand(0,2)];  //ultimo della battuta: uno dei gradi dell'accordo
	pitchPattern[rhythmPattern.maxIndex] = chordNotes[0];

	if(rhythmPattern.size>1,{
		for (2, rhythmPattern.size-1,{
			arg i;
			if(rhythmPattern[i-1]!=0.5,{	pitchPattern[i-1] = chordNotes[rrand(0,2)];},{});
			if(pitchPattern[i-1]=='***',{
				if(melodyDirection,{
					if(pitchPattern[i-2]>19,{pitchPattern[i-1] = pitchPattern[i-2]-1},{pitchPattern[i-1] = pitchPattern[i-2]+1});
					},{
					if(pitchPattern[i-2]>0,{pitchPattern[i-1] = pitchPattern[i-2]-1},{pitchPattern[i-1] = pitchPattern[i-2]+1});
				})},
			{});
			if(pitchPattern[i-1]>19,{pitchPattern=chordNotes[rrand(0,2)];},{});
		});},{});

	// se c'e' dissonanza...
	if(varDissonance>0,{
		if(lengthDissonance.size>1,{
			for (2, lengthDissonance.size-1,{
				arg i;
				if(lengthDissonance[i-1]!=0.5,{ pitchPattern[i-1] = chordNotes[rrand(0,2)]+1;},{});
					if(pitchPattern[i-1]=='***',{
						if(melodyDirection,{
							if(pitchPattern[i-2]>19,{pitchPattern[i-1] = pitchPattern[i-2]-(rrand(0,4))},{pitchPattern[i-1] = pitchPattern[i-2] + (rrand(1,5))});
						},{
					if(pitchPattern[i-2]>0,{pitchPattern[i-1] = pitchPattern[i-2]-(rrand(0,7))},{pitchPattern[i-1] = pitchPattern[i-2]+(rrand(1,7))});
					})},
				{});
			if(pitchPattern[i-1]>19,{pitchPattern=chordNotes[rrand(0,2)]+1;},{});
			//pitchPattern.postln;
		});},{});	
	},{});	
	
	
		
	//	seleziona tema
	if((themeFlag<themeLength).and(beatCounter>16),{
		themeFlag = themeFlag + 1;
		themePitchArray = themePitchArray.add(pitchPattern);
		themeRhythmArray = themeRhythmArray.add(rhythmPattern);
		themeChordArray = themeChordArray.add(chordNotes);
		"costruendo il tema, battuta numero ".post;
		themeFlag.postln;
		quarti = 2;
		case{themeFlag-1 == 3}{quarti = rrand(1,3);}
		    {themeFlag-1 == 6}{quarti = 3};
		},{});
	
	lengthAdjustment.(1);

};

lengthAdjustment = { |x|
	if((currentRhythmSet==0).and(rhythmSetCounter[0]/beatCounter > 0.2),{
		~lengthProbabilityMatrix[0][0] = ~lengthProbabilityMatrix[0][0]+0.04;
		~lengthProbabilityMatrix[0][1] = ~lengthProbabilityMatrix[0][1]-0.01;
		~lengthProbabilityMatrix[0][2] = ~lengthProbabilityMatrix[0][2]-0.01;
		~lengthProbabilityMatrix[0][3] = ~lengthProbabilityMatrix[0][3]-0.01;
		~lengthProbabilityMatrix[0][4] = ~lengthProbabilityMatrix[0][4]-0.01;
		},{});
};


///////////////////// function definition for harmonicProgression
harmonicProgression = { |x|
	var current;
	1.do{|i|
		var condition;
		current = ~accMatrix[x].windex;
		currentChord = current;
	};
	nuAccompaniment = current;
};


///////////////////// setting variables
currentRhythmSet = rrand(0,3);
rhythmSetCounter[currentRhythmSet] = rhythmSetCounter[currentRhythmSet] + 1; // quante volte abbiamo pescato da quell'insieme
startingLength = length[currentRhythmSet].choose;
beatCounter=0;
themeFlag=0;
themePitchArray=[];
themeChordArray=[];
themeRhythmArray=[];
themeActive = false;
randomNote=0;
proxMod = 6;
currentChord = [0,3,4].choose;
nuAccompaniment = harmony[currentChord];
chordNotes = nuAccompaniment;
~actualTones = harmony[currentChord];
accompanimentStream = Pseq(nuAccompaniment, inf).asStream; // accompaniment
currentTone = ~notes.indexOf(startingTone);
nextChord = nil;
currentCounter=0;
mod5=0;
mod4=0;
counterDissonance = 6;
proxVeryHigh = 0.7;
proxHigh = 0.5;
proxMed = 0.3;
proxLow = 0.2;

///////////////////// accompaniment fellow
accompanimentTask = Task({
	loop({
		beatCounter = beatCounter + 1;
		currentCounter=currentCounter+1;
		if (beatCounter == 1, {currentChord = [0,3,4].choose;},{});
		if (beatCounter%8 == 0, {currentChord = 0},{});
		if (beatCounter%8 == 7, {currentChord = 4},{});
		

//////////////////////// REAL TIME SELECTION
		~tempo = 200*(skin+0.1);
		if(proximity>proxHigh,{
			mode = "Maj";
			melodyDirection = true; // false -> basso
			proxMod=3;
			quarti = 3;
			},{
			mode = "HMin";
			melodyDirection = false; // false -> basso
			proxMod = 7;
			quarti = 2;
		});
		
		if(proximity<proxLow,{
			quarti = 0;
		},{});
		
		if(proximity<proxMed,{
			var tmp = proximity*(-20);
			randomNote = 12+tmp; // va da 12 al peggio a 4
		},{randomNote = 0});
		
		// con una certa probabilita' ogni volta che peschi una nota la metti a caso: random(3,12)<=randomNote la metti a caso 
		
		case{mode == "HMin"}{harmony = harmonyHMin;grades = gradesHMin}
		{mode == "Maj"}{harmony = harmonyMaj;grades = gradesMaj};
		
		volRangeSolo = heart;
		volRangeAcc = heart;


	/// gestione modulazione

		if((currentCounter>7).and(mod5==0).and(mod4==0).and(rrand(1,10)>proxMod).and((currentChord == 0).or(currentChord == 5)),{
			var prob;
			prob = [4,5].wchoose([0.5,0.5]);	// con uguale probabilita' modula in quarta o in quinta
			case{prob==5}{
					if(currentChord == 0,{
						nextChord = 5;
					},{});
					if(currentChord == 5,{
						nextChord = [5,4].wchoose([0.70,0.30]);
					},{});	
					"modulazione di quinta".postln;
					mod5=1;	
					gradesMaj = [6,7,9,11,12,14,16,18,19,21,23,24,26,28,30,32,34];
					gradesHMin = [6,7,9,10,12,14,15,18,19,21,22,24,26,27,30,32,34];
					// currentCounter=0;
				}{prob==4}{ 					//vado al quarto grado
					if(currentChord==0,{
						"modulazione di quarta".postln;
						mod4 = 1;
						gradesMaj = [4,5,7,9,10,12,14,16,17,19,21,22,24,26,28,29,32];
						gradesHMin = [4,5,7,8,10,12,13,16,17,19,20,22,24,25,28,29,32];
						//harmonyMaj=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];
						//harmonyHMin=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];
						currentChord = 5;
						nextChord = 0;
						currentTone = currentTone;
						// currentCounter = 0;
					},{});
				}
			},{});
			
		case{mod5==1}{mod5 = 2;	}
			{mod5>1}{mod5 = mod5+1;};
			
		case{mod4==1}{mod4 = 2;	currentChord = [4,1,6].wchoose([0.18,0.75,0.7])}
			{mod4>1}{mod4 = mod4+1;};
			
		if((mod5>6).and(currentChord==0),{	// condizione di terminazione della modulazione di quinta
			mod5 = 0;
			currentTone = currentTone;
			"modulazione di quinta terminata".postln;
			gradesMaj = [-1,0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31];
			gradesHMin = [-1,0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31];
			nextChord=0;
			currentCounter=0;
			},{});
				
		case{nextChord==[0,3]}{currentChord = 0; nextChord=3;}
			{nextChord==3}{currentChord = [1,3].wchoose([0.25,0.75]); nextChord=nil;};
		
		if((mod4>6).and(currentChord==0),{	// condizione di terminazione della modulazione di quarta
			mod4 = 0;
			currentTone = currentTone;
			"modulazione di quarta terminata".postln;
			gradesMaj = [-1,0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31];
			gradesHMin = [-1,0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31];
			nextChord=[0];
			currentCounter=0;
		},{});	
		case{nextChord==[4,0]}{currentChord = 4; nextChord=0;}
			{nextChord==0}{currentChord = 0; nextChord=nil;};	
		chordNotes = harmony[currentChord];
		
		~actualTones = chordNotes;
		soloLine.(1);
		
		// riseleziono il tema a caso
		if ((proximity>proxMed).and(themeFlag==themeLength).and(rrand(0,6)>4),{
			// entro solo se il tema e'stato costruito
			if (themeCounter==themeLength,{
				"THEME SELECTED".postln;
				themeCounter = 0;
				},{});
			},{});
		
		if((proximity>proxVeryHigh).and(themeFlag==themeLength),{
			if (themeCounter==themeLength,{
				"THEME SELECTED".postln;
				themeCounter = 0;
				},{});
		},{});
	
		if ((themeCounter<themeLength),{
			"Theme bar number ".post;
			(themeCounter+1).postln;
			pitchPattern = themePitchArray[themeCounter];
			chordNotes = themeChordArray[themeCounter];
			rhythmPattern = themeRhythmArray[themeCounter];
			quarti = 0;
			case{themeCounter == 3}{quarti = rrand(1,3);}
			    {themeCounter == 6}{quarti = 3}
			    {themeCounter == 7}{quarti = rrand(1,3);};
			themeCounter = themeCounter +1;
			},{});

		"Degree:".post; (currentChord+1).post;
		"  Chord:".post; ~notes[(grades[chordNotes]+currentTone)%12].post;
		"  Length:".post; rhythmPattern.post;
		pitchStream = Pseq(pitchPattern, inf).asStream;
		rhythmStream = Pseq(rhythmPattern, inf).asStream;
		// actual pitch to be played (pretend we are in Maj Scale):
		// 60 is the central C, we just take the grades of the chosen pattern in the mapped mode
		case{quarti==0}{
				m.noteOn(0, 47+currentTone+grades[chordNotes[0]], 120*volRangeAcc); m.noteOn(16, (47+currentTone+grades[chordNotes[1]]), 100*volRangeAcc);  m.noteOn(16, (47+currentTone+grades[chordNotes[2]]), 100*volRangeAcc);
				(4*(60/~tempo)).wait;
				m.noteOff(0, 47+currentTone+grades[chordNotes[0]], 120*volRangeAcc); m.noteOff(16, (47+currentTone+grades[chordNotes[1]]), 100*volRangeAcc); m.noteOff(16, (47+currentTone+grades[chordNotes[2]]), 100*volRangeAcc);
				
			}

			{quarti==1}{
				m.noteOn(0, 35+currentTone+grades[chordNotes[0]], 120*volRangeAcc);
				(3*(60/~tempo)).wait;

				2.do{ |i|
					m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
				};

				m.noteOff(0, 35+currentTone+grades[chordNotes[0]], 120*volRangeAcc);
			}
			
			{quarti==2}{
				m.noteOn(0, 35+currentTone+grades[chordNotes[0]], 120*volRangeAcc);
				(2*(60/~tempo)).wait;
				2.do{ |i|
					m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
				};
				2.do{ |i|
					m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
				};
				m.noteOff(0, 35+currentTone+grades[chordNotes[0]], 120*volRangeAcc);
			}

			{quarti==3}{
				m.noteOn(0, 35+currentTone+grades[chordNotes[0]], 120*volRangeAcc);
				2.do{ |i|
					m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
				};
				2.do{ |i|
					m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
				};
				if ((rrand(0,1) > 0).and(0 == 0),{
					2.do{ |i|
						m.noteOn(16, 47+currentTone+grades[chordNotes[i]+1], 80*volRangeAcc);
						(4*(60/(8*~tempo))).wait;
						m.noteOff(16, 47+currentTone+grades[chordNotes[i]+1], 80*volRangeAcc);
					};
				},{
					2.do{ |i|
						m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
						(4*(60/(8*~tempo))).wait;
						m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					};
				});
				2.do{ |i|
					m.noteOn(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(16, 47+currentTone+grades[chordNotes[i]], 80*volRangeAcc);
				};
				
				m.noteOff(0, 35+currentTone+grades[chordNotes[0]], 120*volRangeAcc);
			};

		harmonicProgression.(currentChord);
		rhythmSetCounter[currentRhythmSet] = rhythmSetCounter[currentRhythmSet] + 1;
		"".postln;

	});
});


///////////////////// solo fellow
melody1Task = Task({
	loop({arg tmpVel;
		var tmpPitch = pitchStream.value;
		var tmpLength =  (60/~tempo)*rhythmStream.value; // controllo sui BPM

		// actual pitch to be played (pretend we are in Maj Scale):
		// 60 is the central C, we just take the grades of the chosen pattern in the mapped mode
		absolutePitch = 59+currentTone+grades[tmpPitch];
		
		if(rrand(4,12) <= randomNote,{
			absolutePitch = absolutePitch + rrand(-1*randomNote,1*randomNote)},{}
		);
	
		tmpVel = rrand(90,120)*volRangeSolo;
		delay = rrand(0,0.04)-0.02;
		delay.wait;
		m.noteOn(1, absolutePitch, tmpVel);
		//m.noteOn(2, absolutePitch, tmpVel);
		(tmpLength-delay).wait;
		m.noteOff(1, absolutePitch, tmpVel);
		//m.noteOff(2, absolutePitch, tmpVel);
	});
});


soloLine.(1);
pitchStream = Pseq(pitchPattern, inf).asStream;
rhythmStream = Pseq(rhythmPattern, inf).asStream;

accompanimentTask.start;
melody1Task.start;
)
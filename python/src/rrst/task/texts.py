"""Instruction texts, from task/RRST_2-0/code/loadParams.m (English "e", Danish "d").

MATLAB's "\\n \\n" sequences are written as newlines. The calibration screen is the
MATLAB text without its "You can continue in" line, as main.m shows it. The Danish
calibration text is English in loadParams.m too (never translated).
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Texts:
    task: str
    conf: str
    conf_anchors: tuple
    calib: str
    start: str
    get_ready: str
    prepare_first: str
    inhale1: str
    inhale2: str
    isi: str
    question: str
    pause: str
    pause_start: str
    end: str
    eq_intro: str
    questions: tuple          # (label, question, (left anchor, right anchor))


def _t(s):
    """MATLAB DrawFormattedText string -> text with newlines."""
    return s.replace(" \\n ", "\n").replace("\\n ", "\n").replace(" \\n", "\n").replace("\\n", "\n")


_EN_TASK_CONF = ("WELCOME TO THE BREATH SENSITIVITY TASK! \\n \\n \\n \\n \\n \\n On each trial, you will take two breaths (inhalations).  \\n \\n Breathe shallowly and pace your inhalations with the expanding circle. \\n \\n \\n \\n Then, decide which of the two breaths was more difficult. \\n \\n First breath - Left mouse button             or            Second breath - Right mouse button \\n \\n \\n \\n Then, rate how confident you are in your choice using the slider. \\n \\n Press 'SPACE' to start...")
_EN_TASK_NOCONF = ("WELCOME TO THE BREATH SENSITIVITY TASK! \\n \\n \\n \\n \\n \\n On each trial, you will take two breaths (inhalations).  \\n \\n Breathe shallowly and pace your inhalations with the expanding circle. \\n \\n \\n \\n Then, decide which of the two breaths was more difficult. \\n \\n First breath - Left mouse button             or            Second breath - Right mouse button \\n \\n \\n \\n Press 'SPACE' to start...")
_DA_TASK_CONF = ("VELKOMMEN TIL VEJRTRÆKNINGSFØLSOMHEDSOPGAVEN! \\n \\n \\n \\n \\n \\n I hver runde skal du tage to åndedrag (indåndinger). \\n\\n Tag skarpe og overfladiske åndedrag og forsøg at indånde jævnt, mens cirklen på skærmen udvider sig. \\n \\n \\n \\n  Efterfølgende vil du blive spurgt om, hvilken af de to indåndinger, der var mest udfordrende. \\n \\n Første åndedrag - tryk VENSTRE museknap       eller         Andet åndedrag - tryk på HØJRE museknap \\n \\n \\n \\n Bagefter skal du vurdere, hvor sikker du var på dit valg ved at bruge markøren på skalaen. \\n \\n Tryk på “MELLEMRUMSTASTEN” for at fortsætte…")
_DA_TASK_NOCONF = ("VELKOMMEN TIL VEJRTRÆKNINGSFØLSOMHEDSOPGAVEN! \\n \\n \\n \\n \\n \\n I hver runde skal du tage to åndedrag (indåndinger). \\n\\n Tag skarpe og overfladiske åndedrag og forsøg at indånde jævnt, mens cirklen på skærmen udvider sig. \\n \\n \\n \\n  Efterfølgende vil du blive spurgt om, hvilken af de to indåndinger, der var mest udfordrende. \\n \\n Første åndedrag - tryk VENSTRE museknap       eller         Andet åndedrag - tryk på HØJRE museknap \\n \\n \\n \\n Tryk på “MELLEMRUMSTASTEN” for at fortsætte…")
_CALIB = "WELCOME TO THE BREATH SENSITIVITY TASK! \\n \\n \\n \\n \\n Please wait while the apparatus calibrates.\\n \\n "

_EN = dict(
    conf="How confident are you in your choice?",
    conf_anchors=("Guess", "Certain"),
    calib=_CALIB,
    start="The experiment will start now. Press 'SPACE' to start.",
    get_ready="Get ready",
    prepare_first="Get ready to inhale in \\n \\n",
    inhale1="Take the first inhale...",
    inhale2="Take the second inhale...",
    isi="Exhale... \\n \\n Get ready to inhale in \\n \\n",
    question="Which breath was harder? \\n \\n First breath (L)     or     Second breath (R)",
    pause="Take a short break. Please stand up and move around. \\n \\n Remember to take sharp and shallow breaths during the task. \\n \\n \\n \\n You can continue in \\n \\n",
    pause_start="You can continue now. \\n \\n When you are ready to continue, press 'SPACE'... ",
    end="You have completed the session. Thank you!",
    eq_intro="Please answer a few quick questions about how you felt during the Breath Sensitivity Task. \\n \\n Press 'SPACE' to continue...",
    questions=(
        ("TaskGeneral", "I find the task", ("Not unpleasant", "Very unpleasant")),
        ("Dizzy", "I feel dizzy / lightheaded.", ("Not at all", "Completely")),
        ("Breathless", "I feel breathless / have trouble breathing.", ("Not at all", "Completely")),
        ("Asthma", "If you have asthma, rate the severity of your symptoms in the last week.",
         ("No asthma / none", "Very severe")),
    ),
)

_DA = dict(
    conf="Hvor sikker var du på dit valg?",
    conf_anchors=("Gæt", "Helt sikker"),
    calib=_CALIB,
    start="Eksperimentet starter nu. Tryk på MELLEMRUMSTASTEN",
    get_ready="Gør dig klar…",
    prepare_first="Gør dig klar til at ånde ind om \\n \\n",
    inhale1="Tag den første indånding…",
    inhale2="Tag den anden indånding…",
    isi="Ånd ud… \\n\\n Gør dig klar til at ånde ind om \\n \\n",
    question="Hvilket åndedrag var mest udfordrende \\n\\n Det første (Venstre) eller det andet (Højre)",
    pause="Tag en kort pause. Rejs dig op og bevæg dig. \\n \\n Husk at tage skarpe og overfladiske indåndinger undervejs i opgaven. \\n \\n \\n \\n Du kan fortsætte om \\n \\n",
    pause_start="Du kan nu fortsætte. \\n \\n Tryk på “MELLEMRUMSTASTEN” for at fortsætte... ",
    end="Du har gennemført sessionen. Tak!",
    eq_intro="Besvar venligst nogle få enkle spørgsmål om, hvordan du havde det under Vejrtrækningsfølsomhedsopgaven. \\n \\n Tryk på “MELLEMRUMSTASTEN” for at fortsætte…",
    questions=(
        ("TaskGeneral", "Jeg fandt opgaven", ("Ikke ubehageligt", "Meget ubehageligt")),
        ("Dizzy", "Jeg føler mig svimmel / ør.", ("Slet ikke", "Fuldstændigt")),
        ("Breathless", "Jeg føler mig åndeløse / forpustet / har besvær ved at trække vejret.",
         ("Slet ikke", "Fuldstændigt")),
        ("Asthma", "Hvis du lider af astma, vurder da alvorsgraden af dine symptomer i løbet af den sidste uge.",
         ("Ingen astma /ingen symptomer", "Meget alvorlige symptomer")),
    ),
)


def texts(language, confidence):
    if language == "e":
        d, task = _EN, (_EN_TASK_CONF if confidence else _EN_TASK_NOCONF)
    elif language == "d":
        d, task = _DA, (_DA_TASK_CONF if confidence else _DA_TASK_NOCONF)
    else:
        raise ValueError('language must be "e" (English) or "d" (Danish).')
    return Texts(task=_t(task), **{k: (_t(v) if isinstance(v, str) else v) for k, v in d.items()})

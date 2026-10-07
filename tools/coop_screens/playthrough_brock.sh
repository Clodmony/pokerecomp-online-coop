# Both players play the opening on a new campaign and walk, fight and talk their
# own way to BROCK's badge, sharing the story (#48; test cases S05, W01, W03, W09, B01, B15).
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P2_TOOL=coop_autoplay
P1_ARGS="opening speed=4 ball=0 shots=$out"
P2_ARGS="opening speed=4 ball=1 shots=$out"
P2_DELAY=25
DURATION=3600

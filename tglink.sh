#!/bin/sh

test $# -ne 2 && echo "Usage: <contact> <if-addr>/<bits>" >&2 && exit 1

CONTACT=$1
NETWORK=$2

MYNAME=$(telegram-cli -WCRMDe 'get_self' | awk '/^User /{print $2; exit}')

test -z $MYNAME && echo "Error: you are not defined" >&2 && exit 2

TGPTY="${HOME}/.tgpty"

TGLINK="${HOME}/.tglink"
trap "rm $TGLINK" INT TERM
test ! -p $TGLINK && mkfifo $TGLINK

data_recv() {
    stdbuf -oL awk -vTYPE=$1 -vNAME=$CONTACT -vMMC=5 '
                  BEGIN { RGXP="^ \\[..:..\\]  "NAME" (>>>|»»») "TYPE" [0-9]{9} " }
                  $0~RGXP {
                      I=int($5); if(I==1) { ID=0; delete MSG; }
                      if(I>ID) MSG[I]=$6;
                      if(length(MSG)>MMC) { ID=I; for(I in MSG) { I=int(I); ID=I<ID?I:ID; } }
                      for(FND=1;FND;) { FND=0; for(I in MSG) { I=int(I); if(I==ID+1) { print MSG[I]; ID=I; delete MSG[I]; FND=1; } } }
                  }' |
        base64io -d
}

data_send() {
    base64io -w500 -t$2 |
        stdbuf -oL awk -vTYPE=$1 -vNAME=$CONTACT '
            BEGIN{ system("sleep 1"); }
            { printf("msg %s %s %09d %s\n",NAME,TYPE,++ID,$0) }'
}

cat $TGLINK |
    # message limiter: 50msg in 20s
    stdbuf -oL awk -vMMC=50 -vPRD=20 '
                    /!repeat/ { $0=LAST; system("sleep 1"); }
                    {
                        NOW=systime(); OLD=NOW; CNT=0;
                        for(T in MSG) { T=int(T); if(T+PRD>NOW) { OLD=T<OLD?T:OLD; CNT+=MSG[T]; } else delete MSG[T]; }
                        if(CNT>=MMC) { system("sleep "PRD+OLD-NOW); delete MSG[OLD]; } 
                        MSG[systime()]++; LAST=$0; print $0;
                    }' |
    telegram-cli -WCRM |
    tee >(stdbuf -oL awk '/FAIL: 38: can not parse arg #1/{ print "!repeat" }' > $TGLINK) |
    # exec command: !command
    tee >(stdbuf -oL awk -vNAME=$CONTACT -vQ="'" '
                        BEGIN { RGXP="^ \\[..:..\\]  "NAME" (>>>|»»») !" }
                        $0~RGXP {
                            RES=""; CMD=gensub(RGXP,"","1");
                            CMD="timeout 10 sh -c \""gensub("\"","\\\"","G",CMD)"\" 2>&1";
                            while( ( CMD | getline LINE ) > 0 ) {
                                if((length(RES) + length(LINE))>4092) break;
                                RES=RES ? RES"\\n"LINE : LINE;
                            }
                            RET=close(CMD);
                            if(     RET==32512) RES="😕";                    # unknown
                            else if(RET==36096) RES=RES"\\n😳";              # overflow
                            else if(RET==31744) RES=RES ? RES"\\n😡" : "😡"; # timeout 
                            else if(!RES) RES=RET ? "😞" : "😊";             # empty
                            print "msg",NAME,Q gensub(Q,"\\\\"Q,"G",RES) Q;
                        }' > $TGLINK) |
    # tun device: if-addr/bits
    tee >(data_recv T | sudo socat - TUN:${NETWORK},up                                                       | data_send T  -1 > $TGLINK) |
    # shell client
    tee >(data_recv C | socat - pty,link=$TGPTY,raw,echo=0                                                   | data_send S  -1 > $TGLINK) |
    # shell server
    tee >(data_recv S | socat - system:"while test -t 0; do $SHELL; done",pty,ctty,stderr,setsid,sigint,sane | data_send C 0.1 > $TGLINK) |
    # tg output
    cat

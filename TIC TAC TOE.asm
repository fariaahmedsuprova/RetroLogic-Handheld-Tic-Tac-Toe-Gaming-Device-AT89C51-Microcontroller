;========================================================
; Tic-Tac-Toe for AT89C51
; LCD 20x4 in 4-bit mode  |  Keypad 4x4
;
; CHANGES FROM ORIGINAL:
;   BUG FIX 1 - P3 init: was #00H, corrected to #0FFH
;   BUG FIX 2 - Status line: DRAW_BOARD now called AFTER
;               TOGGLE_TURN so correct player's turn shown
;   BUG FIX 3 - Double draw: removed stray DRAW_BOARD
;               from inside AI_DONE; board only drawn once
;               per event now
;   NEW AI    - 7-priority enhanced rule-based AI:
;               1. Win  (complete own line)
;               2. Block (stop opponent win)
;               3. Fork Attack (create 2 threats at once)
;               4. Block Fork (prevent opponent fork)
;               5. Center
;               6. Opposite Corner (counter corner play)
;               7. Any Corner
;               8. Any Side
;========================================================

            ORG     0000H
            AJMP    START

;========================================================
; CONSTANTS
;========================================================
XMARK       EQU     01H
OMARK       EQU     02H

MODE_PVP    EQU     00H
MODE_AI     EQU     01H

;========================================================
; RAM MAP
;========================================================
CELL1       EQU     30H
CELL2       EQU     31H
CELL3       EQU     32H
CELL4       EQU     33H
CELL5       EQU     34H
CELL6       EQU     35H
CELL7       EQU     36H
CELL8       EQU     37H
CELL9       EQU     38H

MODEVAR     EQU     39H
TURN        EQU     3AH
WINNER      EQU     3BH
KEYVAL      EQU     3CH
MOVECNT     EQU     3DH
FLAGS       EQU     3EH
TEMP        EQU     3FH

ADR1        EQU     40H
ADR2        EQU     41H
ADR3        EQU     42H
VAL1        EQU     43H
VAL2        EQU     44H
VAL3        EQU     45H
TARGET      EQU     46H

; --- New variables for enhanced AI fork detection ---
FORK_CELL   EQU     47H     ; cell RAM address under fork test (30H..38H)
THREAT_CNT  EQU     48H     ; threat count returned by COUNT_THREATS

;========================================================
; START
;========================================================
START:
            MOV     SP,#70H

            MOV     P0,#0FFH
            MOV     P1,#0FFH
            MOV     P2,#00H
            MOV     P3,#0FFH        ; BUG FIX 1: was #00H (pulled INT/UART pins low)

            ACALL   LCD_INIT

;========================================================
; MAIN MENU
;========================================================
MAIN_MENU:
            ACALL   CLEAR_BOARD
            MOV     MODEVAR,#00H
            MOV     TURN,#XMARK
            MOV     WINNER,#00H
            MOV     MOVECNT,#00H
            ACALL   SHOW_MENU

WAIT_MODE:
            ACALL   GET_KEY_BLOCK
            MOV     KEYVAL,A

            CJNE    A,#0AH,CHK_AI_MODE      ; Row-A col-4 => PvP
            MOV     MODEVAR,#MODE_PVP
            LJMP    GAME_INIT

CHK_AI_MODE:
            CJNE    A,#0BH,CHK_MENU_RESET   ; Row-B col-4 => PvAI
            MOV     MODEVAR,#MODE_AI
            LJMP    GAME_INIT

CHK_MENU_RESET:
            CJNE    A,#0CH,WAIT_MODE        ; ON/C key => reset
            LJMP    MAIN_MENU

;========================================================
; GAME INIT
;========================================================
GAME_INIT:
            ACALL   CLEAR_BOARD
            MOV     TURN,#XMARK
            MOV     WINNER,#00H
            MOV     MOVECNT,#00H
            ACALL   DRAW_BOARD

;========================================================
; GAME LOOP
;========================================================
GAME_LOOP:
            MOV     A,MODEVAR
            JZ      HUMAN_TURN              ; PVP => always human

            MOV     A,TURN
            CJNE    A,#OMARK,HUMAN_TURN     ; AI mode but X turn => human
            ACALL   AI_MOVE
            ACALL   CHECK_WINNER
            MOV     A,WINNER
            JNZ     GAME_OVER
            ACALL   CHECK_DRAW
            MOV     A,WINNER
            JNZ     GAME_OVER
            ACALL   TOGGLE_TURN
            ACALL   DRAW_BOARD              ; BUG FIX 2: draw AFTER toggle
            LJMP    GAME_LOOP               ;            => shows "X TURN" correctly

;========================================================
; HUMAN TURN
;========================================================
HUMAN_TURN:
WAIT_HUMAN_KEY:
            ACALL   GET_KEY_BLOCK
            MOV     KEYVAL,A

            CJNE    A,#0CH,CHK_GAME_KEY
            LJMP    MAIN_MENU

CHK_GAME_KEY:
            ACALL   KEY_TO_ADDR
            JNC     WAIT_HUMAN_KEY          ; invalid key code, ignore

            MOV     A,@R0
            JZ      PLACE_HUMAN
            ACALL   SHOW_INVALID            ; cell occupied
            LJMP    WAIT_HUMAN_KEY

PLACE_HUMAN:
            MOV     A,TURN
            MOV     @R0,A
            INC     MOVECNT
            ; BUG FIX 2+3: removed early DRAW_BOARD here;
            ; now drawn after TOGGLE_TURN so status is correct
            LCALL   CHECK_WINNER
            MOV     A,WINNER
            JNZ     GAME_OVER
            LCALL   CHECK_DRAW
            MOV     A,WINNER
            JNZ     GAME_OVER
            LCALL   TOGGLE_TURN
            ACALL   DRAW_BOARD              ; draw after toggle => correct next-turn status
            LJMP    GAME_LOOP

;========================================================
; GAME OVER
;========================================================
GAME_OVER:
            LCALL   DRAW_BOARD              ; BUG FIX 3: only ONE draw call now

WAIT_RESET_KEY:
            LCALL   GET_KEY_BLOCK
            CJNE    A,#0CH,WAIT_RESET_KEY
            LJMP    MAIN_MENU

;========================================================
; CLEAR BOARD
;========================================================
CLEAR_BOARD:
            MOV     CELL1,#00H
            MOV     CELL2,#00H
            MOV     CELL3,#00H
            MOV     CELL4,#00H
            MOV     CELL5,#00H
            MOV     CELL6,#00H
            MOV     CELL7,#00H
            MOV     CELL8,#00H
            MOV     CELL9,#00H
            RET

;========================================================
; TOGGLE TURN
;========================================================
TOGGLE_TURN:
            MOV     A,TURN
            CJNE    A,#XMARK,SET_X_TURN
            MOV     TURN,#OMARK
            RET
SET_X_TURN:
            MOV     TURN,#XMARK
            RET

;========================================================
; KEY -> CELL ADDRESS
; Input : A = key code (01H..09H = cells 1..9)
; Output: R0 = cell RAM address, C=1 if valid
;         C=0 if key code not a board cell
;========================================================
KEY_TO_ADDR:
            CJNE    A,#01H,KT2
            MOV     R0,#CELL1
            SETB    C
            RET
KT2:        CJNE    A,#02H,KT3
            MOV     R0,#CELL2
            SETB    C
            RET
KT3:        CJNE    A,#03H,KT4
            MOV     R0,#CELL3
            SETB    C
            RET
KT4:        CJNE    A,#04H,KT5
            MOV     R0,#CELL4
            SETB    C
            RET
KT5:        CJNE    A,#05H,KT6
            MOV     R0,#CELL5
            SETB    C
            RET
KT6:        CJNE    A,#06H,KT7
            MOV     R0,#CELL6
            SETB    C
            RET
KT7:        CJNE    A,#07H,KT8
            MOV     R0,#CELL7
            SETB    C
            RET
KT8:        CJNE    A,#08H,KT9
            MOV     R0,#CELL8
            SETB    C
            RET
KT9:        CJNE    A,#09H,KT_BAD
            MOV     R0,#CELL9
            SETB    C
            RET
KT_BAD:
            CLR     C
            RET

;========================================================
; DRAW BOARD ON LCD
; Board layout on screen (matches numpad):
;   LCD line 1:  CELL1 | CELL2 | CELL3   (keys 7 8 9)
;   LCD line 2:  CELL4 | CELL5 | CELL6   (keys 4 5 6)
;   LCD line 3:  CELL7 | CELL8 | CELL9   (keys 1 2 3)
;   LCD line 4:  status / result message
;========================================================
DRAW_BOARD:
            LCALL   LCD_CLEAR

            ; --- LCD Line 1 (DDRAM 0x00, cmd 0x80) ---
            MOV     A,#080H
            LCALL   LCD_CMD
            MOV     A,#01H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA
            MOV     A,#'|'
            LCALL   LCD_DATA
            MOV     A,#02H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA
            MOV     A,#'|'
            LCALL   LCD_DATA
            MOV     A,#03H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA

            ; --- LCD Line 2 (DDRAM 0x40, cmd 0xC0) ---
            MOV     A,#0C0H
            LCALL   LCD_CMD
            MOV     A,#04H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA
            MOV     A,#'|'
            LCALL   LCD_DATA
            MOV     A,#05H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA
            MOV     A,#'|'
            LCALL   LCD_DATA
            MOV     A,#06H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA

            ; --- LCD Line 3 (DDRAM 0x14, cmd 0x94) ---
            MOV     A,#094H
            LCALL   LCD_CMD
            MOV     A,#07H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA
            MOV     A,#'|'
            LCALL   LCD_DATA
            MOV     A,#08H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA
            MOV     A,#'|'
            LCALL   LCD_DATA
            MOV     A,#09H
            LCALL   GET_CELL_CHAR
            LCALL   LCD_DATA

            ; --- LCD Line 4 (DDRAM 0x54, cmd 0xD4) ---
            MOV     A,#0D4H
            LCALL   LCD_CMD

            MOV     A,WINNER
            JZ      DRAW_STATUS             ; no winner yet => show turn

            CJNE    A,#XMARK,CHK_OWIN
            MOV     DPTR,#STR_XWIN
            LCALL   LCD_PRINT_STRING
            RET

CHK_OWIN:
            CJNE    A,#OMARK,SHOW_DRAW_STR
            MOV     DPTR,#STR_OWIN
            LCALL   LCD_PRINT_STRING
            RET

SHOW_DRAW_STR:
            MOV     DPTR,#STR_DRAW
            LCALL   LCD_PRINT_STRING
            RET

DRAW_STATUS:
            MOV     A,MODEVAR
            JZ      STATUS_PVP

            MOV     A,TURN
            CJNE    A,#XMARK,STATUS_AI_O
            MOV     DPTR,#STR_AIX
            LCALL   LCD_PRINT_STRING
            RET
STATUS_AI_O:
            MOV     DPTR,#STR_AIO
            LCALL   LCD_PRINT_STRING
            RET

STATUS_PVP:
            MOV     A,TURN
            CJNE    A,#XMARK,STATUS_PVP_O
            MOV     DPTR,#STR_PVPX
            LCALL   LCD_PRINT_STRING
            RET
STATUS_PVP_O:
            MOV     DPTR,#STR_PVPO
            LCALL   LCD_PRINT_STRING
            RET

;========================================================
; GET DISPLAY CHARACTER FOR CELL INDEX 1..9
; If cell is empty  => show keypad label from LABEL_TABLE
; If cell = XMARK   => 'X'
; If cell = OMARK   => 'O'
;========================================================
GET_CELL_CHAR:
            MOV     TEMP,A
            ADD     A,#2FH          ; index 1 -> 30H (CELL1)
            MOV     R0,A
            MOV     A,@R0
            JZ      EMPTY_CELL_CHAR

            CJNE    A,#XMARK,CHK_O_CHAR
            MOV     A,#'X'
            RET
CHK_O_CHAR:
            MOV     A,#'O'
            RET

EMPTY_CELL_CHAR:
            MOV     A,TEMP
            DEC     A               ; 0-based index for LABEL_TABLE
            MOV     DPTR,#LABEL_TABLE
            MOVC    A,@A+DPTR
            RET

;========================================================
; SHOW MENU
;========================================================
SHOW_MENU:
            LCALL   LCD_CLEAR

            MOV     A,#080H
            LCALL   LCD_CMD
            MOV     DPTR,#STR_TITLE
            LCALL   LCD_PRINT_STRING

            MOV     A,#0C0H
            LCALL   LCD_CMD
            MOV     DPTR,#STR_MODE1
            LCALL   LCD_PRINT_STRING

            MOV     A,#094H
            LCALL   LCD_CMD
            MOV     DPTR,#STR_MODE2
            LCALL   LCD_PRINT_STRING

            MOV     A,#0D4H
            LCALL   LCD_CMD
            MOV     DPTR,#STR_MODE3
            LCALL   LCD_PRINT_STRING
            RET

;========================================================
; SHOW INVALID MOVE MESSAGE
;========================================================
SHOW_INVALID:
            MOV     A,#0D4H
            LCALL   LCD_CMD
            MOV     DPTR,#STR_INVALID
            LCALL   LCD_PRINT_STRING
            LCALL   DELAY_BIG
            LCALL   DRAW_BOARD              ; restore normal board display
            RET

;========================================================
; CHECK WINNER
; Tests all 8 winning lines.
; Sets WINNER = XMARK / OMARK if found, 00H if none.
;========================================================
CHECK_WINNER:
            MOV     WINNER,#00H

            ; Row 1-2-3
            MOV     A,CELL1
            JZ      CW2
            CJNE    A,CELL2,CW2
            CJNE    A,CELL3,CW2
            MOV     WINNER,A
            RET
CW2:
            ; Row 4-5-6
            MOV     A,CELL4
            JZ      CW3
            CJNE    A,CELL5,CW3
            CJNE    A,CELL6,CW3
            MOV     WINNER,A
            RET
CW3:
            ; Row 7-8-9
            MOV     A,CELL7
            JZ      CW4
            CJNE    A,CELL8,CW4
            CJNE    A,CELL9,CW4
            MOV     WINNER,A
            RET
CW4:
            ; Col 1-4-7
            MOV     A,CELL1
            JZ      CW5
            CJNE    A,CELL4,CW5
            CJNE    A,CELL7,CW5
            MOV     WINNER,A
            RET
CW5:
            ; Col 2-5-8
            MOV     A,CELL2
            JZ      CW6
            CJNE    A,CELL5,CW6
            CJNE    A,CELL8,CW6
            MOV     WINNER,A
            RET
CW6:
            ; Col 3-6-9
            MOV     A,CELL3
            JZ      CW7
            CJNE    A,CELL6,CW7
            CJNE    A,CELL9,CW7
            MOV     WINNER,A
            RET
CW7:
            ; Diagonal 1-5-9
            MOV     A,CELL1
            JZ      CW8
            CJNE    A,CELL5,CW8
            CJNE    A,CELL9,CW8
            MOV     WINNER,A
            RET
CW8:
            ; Diagonal 3-5-7
            MOV     A,CELL3
            JZ      CW_END
            CJNE    A,CELL5,CW_END
            CJNE    A,CELL7,CW_END
            MOV     WINNER,A
CW_END:
            RET

;========================================================
; CHECK DRAW
; If WINNER still 0 and all 9 cells filled => WINNER=03H
;========================================================
CHECK_DRAW:
            MOV     A,WINNER
            JNZ     CD_END
            MOV     A,MOVECNT
            CJNE    A,#09H,CD_END
            MOV     WINNER,#03H
CD_END:
            RET

;============================================================
; AI MOVE  -  Enhanced Rule-Based  (plays as OMARK)
;
; Priority order:
;  1. WIN          - if O can complete a line, do it
;  2. BLOCK        - if X is about to win, block it
;  3. FORK ATTACK  - find a cell that creates 2 O threats
;  4. BLOCK FORK   - find a cell where X would get 2 threats
;  5. CENTER       - take cell 5 if free
;  6. OPP CORNER   - if X is in a corner, take opposite corner
;  7. ANY CORNER   - take any free corner
;  8. ANY SIDE     - take any free side
;
; NOTE: No DRAW_BOARD here anymore (BUG FIX 3).
;       Caller draws after TOGGLE_TURN.
;============================================================
AI_MOVE:
            ; --- Priority 1: Win ---
            LCALL   TRY_WIN_O
            JC      AI_PLACED

            ; --- Priority 2: Block ---
            LCALL   TRY_BLOCK_X
            JC      AI_PLACED

            ; --- Priority 3: Fork Attack ---
            LCALL   TRY_FORK_O
            JC      AI_PLACED

            ; --- Priority 4: Block Fork ---
            LCALL   TRY_BLOCK_FORK_X
            JC      AI_PLACED

            ; --- Priority 5: Center ---
            MOV     A,CELL5
            JNZ     AI_OPP_CORNER
            MOV     CELL5,#OMARK
            INC     MOVECNT
            LJMP    AI_PLACED

AI_OPP_CORNER:
            ; --- Priority 6: Opposite Corner ---
            LCALL   TRY_OPP_CORNER
            JC      AI_PLACED

            ; --- Priority 7: Any Corner ---
            LCALL   TRY_ANY_CORNER
            JC      AI_PLACED

            ; --- Priority 8: Any Side ---
            LCALL   TRY_ANY_SIDE
            ; (C may be 0 if board full - shouldn't happen before draw detected)

AI_PLACED:
            RET                             ; return to GAME_LOOP; caller draws board

;========================================================
; TRY WIN O  - find a line with 2 O + 1 empty, place O
;========================================================
TRY_WIN_O:
            MOV     TARGET,#OMARK
            LCALL   TRY_TWO_ANY
            RET

;========================================================
; TRY BLOCK X - find a line with 2 X + 1 empty, block it
;========================================================
TRY_BLOCK_X:
            MOV     TARGET,#XMARK
            LCALL   TRY_TWO_ANY
            RET

;============================================================
; TRY_FORK_O
; Scan all 9 cells in order CELL1..CELL9.
; For each empty cell, simulate placing O there,
; count O winning threats (lines with 2 O + 1 empty).
; If >= 2 threats found => it is a fork cell => place O.
; Return C=1 if placed, C=0 if no fork found.
;
; Uses: FORK_CELL, THREAT_CNT, TARGET, R0
;       (COUNT_THREATS uses ADR1,ADR2,ADR3,R5,R4,R2,DPTR)
;============================================================
TRY_FORK_O:
            MOV     FORK_CELL,#CELL1        ; start at 30H

TFO_LOOP:
            MOV     R0,FORK_CELL
            MOV     A,@R0
            JNZ     TFO_NEXT                ; cell not empty, skip

            ; --- Simulate placing O ---
            MOV     @R0,#OMARK

            ; --- Count O's threats from this position ---
            MOV     TARGET,#OMARK
            LCALL   COUNT_THREATS
            MOV     THREAT_CNT,A

            ; --- Undo simulation (R0 was modified by COUNT_THREATS) ---
            MOV     R0,FORK_CELL
            MOV     @R0,#00H

            ; --- Fork if threats >= 2 ---
            MOV     A,THREAT_CNT
            CJNE    A,#02H,TFO_NOT2         ; branch if A != 2
            LJMP    TFO_FOUND               ; A == 2 => fork
TFO_NOT2:
            JNC     TFO_FOUND               ; C=0 => A > 2 => also fork
            SJMP    TFO_NEXT                ; C=1 => A < 2 => no fork

TFO_FOUND:
            MOV     A,FORK_CELL
            LCALL   PLACE_O_AT_ADDR         ; permanently place O here
            SETB    C
            RET

TFO_NEXT:
            INC     FORK_CELL
            MOV     A,FORK_CELL
            CJNE    A,#39H,TFO_LOOP         ; 39H = CELL9+1
            CLR     C
            RET

;============================================================
; TRY_BLOCK_FORK_X
; Same idea but from X's perspective:
; find a cell where placing X would give X >= 2 threats,
; and place O there to neutralize the fork.
; Return C=1 if placed, C=0 if no X fork found.
;============================================================
TRY_BLOCK_FORK_X:
            MOV     FORK_CELL,#CELL1

TBFX_LOOP:
            MOV     R0,FORK_CELL
            MOV     A,@R0
            JNZ     TBFX_NEXT

            ; --- Simulate placing X ---
            MOV     @R0,#XMARK

            ; --- Count X's threats ---
            MOV     TARGET,#XMARK
            LCALL   COUNT_THREATS
            MOV     THREAT_CNT,A

            ; --- Undo ---
            MOV     R0,FORK_CELL
            MOV     @R0,#00H

            ; --- Block if X would get >= 2 threats ---
            MOV     A,THREAT_CNT
            CJNE    A,#02H,TBFX_NOT2
            LJMP    TBFX_FOUND
TBFX_NOT2:
            JNC     TBFX_FOUND
            SJMP    TBFX_NEXT

TBFX_FOUND:
            MOV     A,FORK_CELL
            LCALL   PLACE_O_AT_ADDR
            SETB    C
            RET

TBFX_NEXT:
            INC     FORK_CELL
            MOV     A,FORK_CELL
            CJNE    A,#39H,TBFX_LOOP
            CLR     C
            RET

;============================================================
; COUNT_THREATS
; Input : TARGET = mark to evaluate (OMARK or XMARK)
;         The test mark must already be placed on the board
; Output: A = number of lines containing exactly 2 of TARGET
;             and 1 empty (= immediate winning threats)
;
; A line is skipped entirely if it contains the opponent mark
; (because that line can never be won by TARGET).
;
; Uses: DPTR, R5 (line counter), R4 (threat count),
;       R2 (mark count per line), R0, ADR1, ADR2, ADR3
;============================================================
COUNT_THREATS:
            MOV     DPTR,#LINE_TABLE
            MOV     R5,#08H                 ; 8 lines to test
            MOV     R4,#00H                 ; threat counter

CT_LOOP:
            ; Load cell indices for this line and convert to RAM addresses
            CLR     A
            MOVC    A,@A+DPTR
            ADD     A,#2FH
            MOV     ADR1,A
            INC     DPTR

            CLR     A
            MOVC    A,@A+DPTR
            ADD     A,#2FH
            MOV     ADR2,A
            INC     DPTR

            CLR     A
            MOVC    A,@A+DPTR
            ADD     A,#2FH
            MOV     ADR3,A
            INC     DPTR

            MOV     R2,#00H                 ; TARGET mark count for this line

            ; --- Check cell 1 of line ---
            MOV     R0,ADR1
            MOV     A,@R0
            JZ      CT_1OK                  ; empty: fine, don't count
            CJNE    A,TARGET,CT_SKIP        ; opponent mark: whole line useless
            INC     R2                      ; it is TARGET mark
CT_1OK:
            ; --- Check cell 2 of line ---
            MOV     R0,ADR2
            MOV     A,@R0
            JZ      CT_2OK
            CJNE    A,TARGET,CT_SKIP
            INC     R2
CT_2OK:
            ; --- Check cell 3 of line ---
            MOV     R0,ADR3
            MOV     A,@R0
            JZ      CT_3OK
            CJNE    A,TARGET,CT_SKIP
            INC     R2
CT_3OK:
            ; Exactly 2 of TARGET with no opponent => 1 empty => threat
            CJNE    R2,#02H,CT_SKIP
            INC     R4

CT_SKIP:
            DJNZ    R5,CT_LOOP

            MOV     A,R4                    ; return threat count
            RET

;========================================================
; TRY_OPP_CORNER
; If X occupies a corner, take the diagonally opposite
; corner (if empty). Disrupts the "opposite corner trap".
; Return C=1 if placed, C=0 otherwise.
;========================================================
TRY_OPP_CORNER:
            MOV     A,CELL1
            CJNE    A,#XMARK,TOC_C3         ; X in CELL1?
            MOV     A,CELL9
            JNZ     TOC_C3                  ; CELL9 not empty, try next
            MOV     CELL9,#OMARK
            INC     MOVECNT
            SETB    C
            RET

TOC_C3:
            MOV     A,CELL3
            CJNE    A,#XMARK,TOC_C7
            MOV     A,CELL7
            JNZ     TOC_C7
            MOV     CELL7,#OMARK
            INC     MOVECNT
            SETB    C
            RET

TOC_C7:
            MOV     A,CELL7
            CJNE    A,#XMARK,TOC_C9
            MOV     A,CELL3
            JNZ     TOC_C9
            MOV     CELL3,#OMARK
            INC     MOVECNT
            SETB    C
            RET

TOC_C9:
            MOV     A,CELL9
            CJNE    A,#XMARK,TOC_FAIL
            MOV     A,CELL1
            JNZ     TOC_FAIL
            MOV     CELL1,#OMARK
            INC     MOVECNT
            SETB    C
            RET

TOC_FAIL:
            CLR     C
            RET

;========================================================
; TRY_ANY_CORNER
; Take any free corner (CELL1, CELL3, CELL7, CELL9).
; Return C=1 if placed, C=0 if all corners occupied.
;========================================================
TRY_ANY_CORNER:
            MOV     A,CELL1
            JNZ     TAC_3
            MOV     CELL1,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAC_3:
            MOV     A,CELL3
            JNZ     TAC_7
            MOV     CELL3,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAC_7:
            MOV     A,CELL7
            JNZ     TAC_9
            MOV     CELL7,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAC_9:
            MOV     A,CELL9
            JNZ     TAC_FAIL
            MOV     CELL9,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAC_FAIL:
            CLR     C
            RET

;========================================================
; TRY_ANY_SIDE
; Take any free side (CELL2, CELL4, CELL6, CELL8).
; Return C=1 if placed, C=0 if all sides occupied.
;========================================================
TRY_ANY_SIDE:
            MOV     A,CELL2
            JNZ     TAS_4
            MOV     CELL2,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAS_4:
            MOV     A,CELL4
            JNZ     TAS_6
            MOV     CELL4,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAS_6:
            MOV     A,CELL6
            JNZ     TAS_8
            MOV     CELL6,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAS_8:
            MOV     A,CELL8
            JNZ     TAS_FAIL
            MOV     CELL8,#OMARK
            INC     MOVECNT
            SETB    C
            RET
TAS_FAIL:
            CLR     C
            RET

;========================================================
; TRY_TWO_ANY
; Scan LINE_TABLE. If a line has 2 TARGET marks + 1 empty,
; place O in the empty cell.
; Return C=1 if placed, C=0 if no such line found.
;========================================================
TRY_TWO_ANY:
            MOV     DPTR,#LINE_TABLE
            MOV     R5,#08H

TT_LOOP:
            CLR     A
            MOVC    A,@A+DPTR
            ADD     A,#2FH
            MOV     ADR1,A
            INC     DPTR

            CLR     A
            MOVC    A,@A+DPTR
            ADD     A,#2FH
            MOV     ADR2,A
            INC     DPTR

            CLR     A
            MOVC    A,@A+DPTR
            ADD     A,#2FH
            MOV     ADR3,A
            INC     DPTR

            MOV     R0,ADR1
            MOV     A,@R0
            MOV     VAL1,A

            MOV     R0,ADR2
            MOV     A,@R0
            MOV     VAL2,A

            MOV     R0,ADR3
            MOV     A,@R0
            MOV     VAL3,A

            ; Case 1: ADR1 empty, ADR2 and ADR3 = TARGET
            MOV     A,VAL1
            JNZ     TT_CASE2
            MOV     A,VAL2
            CJNE    A,TARGET,TT_CASE2
            MOV     A,VAL3
            CJNE    A,TARGET,TT_CASE2
            MOV     A,ADR1
            LCALL   PLACE_O_AT_ADDR
            RET

TT_CASE2:
            ; Case 2: ADR2 empty, ADR1 and ADR3 = TARGET
            MOV     A,VAL2
            JNZ     TT_CASE3
            MOV     A,VAL1
            CJNE    A,TARGET,TT_CASE3
            MOV     A,VAL3
            CJNE    A,TARGET,TT_CASE3
            MOV     A,ADR2
            LCALL   PLACE_O_AT_ADDR
            RET

TT_CASE3:
            ; Case 3: ADR3 empty, ADR1 and ADR2 = TARGET
            MOV     A,VAL3
            JNZ     TT_NEXT
            MOV     A,VAL1
            CJNE    A,TARGET,TT_NEXT
            MOV     A,VAL2
            CJNE    A,TARGET,TT_NEXT
            MOV     A,ADR3
            LCALL   PLACE_O_AT_ADDR
            RET

TT_NEXT:
            DJNZ    R5,TT_LOOP
            CLR     C
            RET

;========================================================
; PLACE_O_AT_ADDR
; Input:  A = cell RAM address (30H..38H)
; Action: places OMARK at that address, increments MOVECNT
; Output: C=1
;========================================================
PLACE_O_AT_ADDR:
            MOV     R0,A
            MOV     @R0,#OMARK
            INC     MOVECNT
            SETB    C
            RET

;========================================================
; KEYPAD SCAN
; Rows -> P1.0..P1.3   (output, drive low one at a time)
; Cols -> P1.4..P1.7   (input,  pulled high)
;
; Key map:
;   Row A (P1=FEH): col1=01H col2=02H col3=03H col4=0AH
;   Row B (P1=FDH): col1=04H col2=05H col3=06H col4=0BH
;   Row C (P1=FBH): col1=07H col2=08H col3=09H col4=0DH
;   Row D (P1=F7H): col1=0CH col2=0EH col3=0FH col4=10H
;========================================================
GET_KEY_BLOCK:
GK_WAIT:
            LCALL   SCAN_KEY
            JZ      GK_WAIT
            LCALL   DELAY_DEB
            LCALL   SCAN_KEY
            JZ      GK_WAIT
            MOV     KEYVAL,A

GK_REL:
            LCALL   SCAN_KEY
            JNZ     GK_REL

            MOV     A,KEYVAL
            RET

SCAN_KEY:
            ; --- Row A ---
            MOV     P1,#0FEH
            NOP
            MOV     A,P1
            ANL     A,#0F0H
            CJNE    A,#0F0H,ROWA_HIT
            LJMP    ROW_B_SCAN

ROWA_HIT:
            CJNE    A,#0E0H,RA2
            MOV     A,#01H
            RET
RA2:        CJNE    A,#0D0H,RA3
            MOV     A,#02H
            RET
RA3:        CJNE    A,#0B0H,RA4
            MOV     A,#03H
            RET
RA4:        CJNE    A,#070H,ROW_B_SCAN
            MOV     A,#0AH
            RET

            ; --- Row B ---
ROW_B_SCAN:
            MOV     P1,#0FDH
            NOP
            MOV     A,P1
            ANL     A,#0F0H
            CJNE    A,#0F0H,ROWB_HIT
            LJMP    ROW_C_SCAN

ROWB_HIT:
            CJNE    A,#0E0H,RB2
            MOV     A,#04H
            RET
RB2:        CJNE    A,#0D0H,RB3
            MOV     A,#05H
            RET
RB3:        CJNE    A,#0B0H,RB4
            MOV     A,#06H
            RET
RB4:        CJNE    A,#070H,ROW_C_SCAN
            MOV     A,#0BH
            RET

            ; --- Row C ---
ROW_C_SCAN:
            MOV     P1,#0FBH
            NOP
            MOV     A,P1
            ANL     A,#0F0H
            CJNE    A,#0F0H,ROWC_HIT
            LJMP    ROW_D_SCAN

ROWC_HIT:
            CJNE    A,#0E0H,RC2
            MOV     A,#07H
            RET
RC2:        CJNE    A,#0D0H,RC3
            MOV     A,#08H
            RET
RC3:        CJNE    A,#0B0H,RC4
            MOV     A,#09H
            RET
RC4:        CJNE    A,#070H,ROW_D_SCAN
            MOV     A,#0DH
            RET

            ; --- Row D ---
ROW_D_SCAN:
            MOV     P1,#0F7H
            NOP
            MOV     A,P1
            ANL     A,#0F0H
            CJNE    A,#0F0H,ROWD_HIT
            LJMP    NO_KEY

ROWD_HIT:
            CJNE    A,#0E0H,RD2
            MOV     A,#0CH
            RET
RD2:        CJNE    A,#0D0H,RD3
            MOV     A,#0EH
            RET
RD3:        CJNE    A,#0B0H,RD4
            MOV     A,#0FH
            RET
RD4:        CJNE    A,#070H,NO_KEY
            MOV     A,#10H
            RET

NO_KEY:
            MOV     P1,#0FFH
            CLR     A
            RET

;========================================================
; LCD ROUTINES
; RS -> P3.6     E -> P3.7
; D4..D7 -> P2.4..P2.7   (4-bit mode)
;========================================================
LCD_INIT:
            CLR     P3.6
            CLR     P3.7
            LCALL   DELAY_BIG

            ; 4-bit init sequence (HD44780 spec)
            MOV     A,#03H
            LCALL   LCD_WRITE_INIT_NIBBLE
            LCALL   DELAY_BIG

            MOV     A,#03H
            LCALL   LCD_WRITE_INIT_NIBBLE
            LCALL   DELAY_SHORT

            MOV     A,#03H
            LCALL   LCD_WRITE_INIT_NIBBLE
            LCALL   DELAY_SHORT

            MOV     A,#02H                  ; switch to 4-bit
            LCALL   LCD_WRITE_INIT_NIBBLE
            LCALL   DELAY_SHORT

            MOV     A,#028H                 ; 2 lines, 5x8 font
            LCALL   LCD_CMD
            MOV     A,#00CH                 ; display on, cursor off
            LCALL   LCD_CMD
            MOV     A,#006H                 ; entry mode
            LCALL   LCD_CMD
            MOV     A,#001H                 ; clear
            LCALL   LCD_CMD
            LCALL   DELAY_BIG
            RET

LCD_CLEAR:
            MOV     A,#001H
            LCALL   LCD_CMD
            LCALL   DELAY_BIG
            RET

LCD_CMD:
            CLR     P3.6
            MOV     TEMP,A

            MOV     A,TEMP
            SWAP    A
            ANL     A,#0FH
            LCALL   LCD_WRITE_INIT_NIBBLE

            MOV     A,TEMP
            ANL     A,#0FH
            LCALL   LCD_WRITE_INIT_NIBBLE

            LCALL   DELAY_SHORT
            RET

LCD_DATA:
            SETB    P3.6
            MOV     TEMP,A

            MOV     A,TEMP
            SWAP    A
            ANL     A,#0FH
            LCALL   LCD_WRITE_INIT_NIBBLE

            MOV     A,TEMP
            ANL     A,#0FH
            LCALL   LCD_WRITE_INIT_NIBBLE

            LCALL   DELAY_SHORT
            RET

LCD_WRITE_INIT_NIBBLE:
            ANL     A,#0FH
            SWAP    A
            ANL     A,#0F0H
            MOV     R7,A

            MOV     A,P2
            ANL     A,#0FH
            ORL     A,R7
            MOV     P2,A

            SETB    P3.7
            LCALL   DELAY_TINY
            CLR     P3.7
            RET

LCD_PRINT_STRING:
LPS1:
            CLR     A
            MOVC    A,@A+DPTR
            JZ      LPS_END
            LCALL   LCD_DATA
            INC     DPTR
            LJMP    LPS1
LPS_END:
            RET

;========================================================
; DELAYS
;========================================================
DELAY_TINY:
            NOP
            NOP
            NOP
            NOP
            RET

DELAY_SHORT:
            MOV     R7,#80
DS1:
            DJNZ    R7,DS1
            RET

DELAY_DEB:
            MOV     R6,#40
DD1:        MOV     R7,#255
DD2:        DJNZ    R7,DD2
            DJNZ    R6,DD1
            RET

DELAY_BIG:
            MOV     R6,#120
DB1:        MOV     R7,#255
DB2:        DJNZ    R7,DB2
            DJNZ    R6,DB1
            RET

;========================================================
; LOOKUP TABLES
;========================================================

; Maps cell index (0-based) to keypad label shown when empty
LABEL_TABLE:
            DB      '7','8','9','4','5','6','1','2','3'

; All 8 winning lines (stored as cell indices 1..9)
LINE_TABLE:
            DB      1,2,3       ; row 1
            DB      4,5,6       ; row 2
            DB      7,8,9       ; row 3
            DB      1,4,7       ; col 1
            DB      2,5,8       ; col 2
            DB      3,6,9       ; col 3
            DB      1,5,9       ; diagonal TL-BR
            DB      3,5,7       ; diagonal TR-BL

;========================================================
; STRINGS (null-terminated)
;========================================================
STR_TITLE:
            DB      'TIC TAC TOE',00H
STR_MODE1:
            DB      '/=PVP   *=AI',00H
STR_MODE2:
            DB      'ON/C = RESET',00H
STR_MODE3:
            DB      'SELECT MODE',00H

STR_PVPX:
            DB      'PVP MODE  X TURN',00H
STR_PVPO:
            DB      'PVP MODE  O TURN',00H
STR_AIX:
            DB      'AI MODE   X TURN',00H
STR_AIO:
            DB      'AI MODE   O TURN',00H

STR_INVALID:
            DB      'INVALID MOVE',00H
STR_XWIN:
            DB      'X WINS  ON/C MENU',00H
STR_OWIN:
            DB      'O WINS  ON/C MENU',00H
STR_DRAW:
            DB      'DRAW    ON/C MENU',00H

            END

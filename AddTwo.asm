TITLE Pacman Game

INCLUDE Irvine32.inc

; Add Windows API imports
includelib kernel32.lib
includelib winmm.lib     ; For playing MP3 files

; External function declarations
Beep PROTO,
    dwFreq:DWORD,
    dwDuration:DWORD

PlaySound PROTO,
    pszSound:PTR BYTE,
    hmod:DWORD,
    fdwSound:DWORD

mciSendStringA PROTO,
    lpszCommand:PTR BYTE,
    lpszReturnString:PTR BYTE,
    cchReturn:DWORD,
    hCallback:DWORD

; Sound flags for PlaySound
SND_SYNC     EQU 00000000h    ; Play synchronously
SND_ASYNC    EQU 00000001h    ; Play asynchronously
SND_FILENAME EQU 00020000h    ; Sound is a path to a file

.data
; Welcome screen
welcomeArt BYTE " .----------------.   .----------------.   .----------------.   .----------------.   .----------------.   .----------------.", 13, 10
          BYTE "| .--------------. | | .--------------. | | .--------------. | | .--------------. | | .--------------. | | .--------------. |", 13, 10
          BYTE "| |   ______     | | | |      __      | | | |     ______   | | | | ____    ____ | | | |      __      | | | | ____  _____  | |", 13, 10
          BYTE "| |  |_   __ \   | | | |     /  \     | | | |   .' ___  |  | | | ||_   \  /   _|| | | |     /  \     | | | ||_   \|_   _| | |", 13, 10
          BYTE "| |    | |__) |  | | | |    / /\ \    | | | |  / .'   \_|  | | | |  |   \/   |  | | | |    / /\ \    | | | |  |   \ | |   | |", 13, 10
          BYTE "| |    |  ___/   | | | |   / ____ \   | | | |  | |         | | | |  | |\  /| |  | | | |   / ____ \   | | | |  | |\ \| |   | |", 13, 10
          BYTE "| |   _| |_      | | | | _/ /    \ \_ | | | |  \ `.___.'\  | | | | _| |_\/_| |_ | | | | _/ /    \ \_ | | | | _| |_\   |_  | |", 13, 10
          BYTE "| |  |_____|     | | | ||____|  |____|| | | |   `._____.'  | | | ||_____||_____|| | | ||____|  |____|| | | ||_____|\____| | |", 13, 10
          BYTE "| |              | | | |              | | | |              | | | |              | | | |              | | | |              | |", 13, 10
          BYTE "| '--------------' | | '--------------' | | '--------------' | | '--------------' | | '--------------' | | '--------------' |", 13, 10
          BYTE " '----------------'   '----------------'   '----------------'   '----------------'   '----------------'   '----------------' ", 0

namePrompt BYTE "Enter your name: ", 0
levelPrompt BYTE "Select level (1-3): ", 0
level1Msg BYTE "Level 1 - Classic Pacman", 0
level2Msg BYTE "Level 2 - Coming Soon!", 0
level3Msg BYTE "Level 3 - Teleport Maze", 0
invalidLevelMsg BYTE "Invalid level. Please select 1-3.", 0
playerName BYTE 32 DUP(0)    ; Buffer for player name
nameMsg BYTE "Player: ", 0
currentLevel BYTE 1          ; Current game level

; Game grid size
gridWidth DWORD 64
gridHeight DWORD 32

; Character representations
wallChar BYTE '#', 0
pacmanChar BYTE 'C', 0
ghostChar BYTE 'G', 0                ; Changed from 'P' to 'G'
vulnerableGhostChar BYTE 'g', 0      ; Changed from 'p' to 'g'
emptyChar BYTE ' ', 0
dotChar BYTE '.', 0
fruitChar BYTE 'F', 0   ; Explicit definition of fruit as 'F'

; Game grid (32x64)
grid BYTE 2048 DUP(?)  ; 32 * 64 = 2048

; Game state variables
lives DWORD 3          ; Player starts with 3 lives
score DWORD 0          ; Player's score
lastCellContent BYTE 0 ; Stores what was under the ghost before it moved
powerUpActive BYTE 0   ; New: 1 if power-up is active, 0 if not
powerUpTimer DWORD 0   ; New: Timer for power-up duration (in game ticks)
powerUpDuration DWORD 200  ; New: Duration of power-up (20 seconds * 10 ticks per second)

; Score and lives display
scoreMsg BYTE "Score: ", 0
livesMsg BYTE "Lives: ", 0

; Console parameters
consoleHandle DWORD ?
cursorInfo CONSOLE_CURSOR_INFO <>
coordScreen COORD <>
rectScreen SMALL_RECT <>
bufferSize COORD <>
bufferCoord COORD <>
charAttr WORD ?
cellsWritten DWORD ?

; Entity positions
pacmanPos DWORD 0      ; Pacman position (row * gridWidth + col)
ghost1Pos DWORD 0      ; Ghost positions
ghost2Pos DWORD 0
ghost3Pos DWORD 0
ghost4Pos DWORD 0
ghost5Pos DWORD 0      ; Fifth ghost for level 2

; Game state
gameRunning BYTE 1     ; 1 = game is running, 0 = game is over
remainingDots DWORD 0  ; Number of dots remaining in the grid
gameEndReason BYTE 0   ; 0 = not ended, 1 = lives lost, 2 = all pellets collected, 3 = quit by player

; Directions for movement
UP_DIR DWORD 0
RIGHT_DIR DWORD 1
DOWN_DIR DWORD 2
LEFT_DIR DWORD 3

; Input key values
KEY_W DWORD 119        ; 'w'
KEY_A DWORD 97         ; 'a'
KEY_S DWORD 115        ; 's'
KEY_D DWORD 100        ; 'd'
KEY_Q DWORD 113        ; 'q' to quit

; Message strings
msgQuit BYTE "Press Q to quit, WASD to move Pacman", 0
msgGameOver BYTE "Game Over!", 0
msgWin BYTE "You Win! All pellets collected!", 0
msgReason BYTE "Reason: ", 0
msgLivesLost BYTE "All lives lost", 0
msgAllPelletsCollected BYTE "All pellets collected", 0
msgQuitGame BYTE "Game quit by player", 0

; Game over ASCII art
gameOverArt BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "        GGGGGGGGGGGGG               AAA               MMMMMMMM               MMMMMMMMEEEEEEEEEEEEEEEEEEEEEE          OOOOOOOOO     VVVVVVVV           VVVVVVVVEEEEEEEEEEEEEEEEEEEEEERRRRRRRRRRRRRRRRR   ", 13, 10
           BYTE "     GGG::::::::::::G              A:::A              M:::::::M             M:::::::ME::::::::::::::::::::E        OO:::::::::OO   V::::::V           V::::::VE::::::::::::::::::::ER::::::::::::::::R  ", 13, 10
           BYTE "   GG:::::::::::::::G             A:::::A             M::::::::M           M::::::::ME::::::::::::::::::::E      OO:::::::::::::OO V::::::V           V::::::VE::::::::::::::::::::ER::::::RRRRRR:::::R ", 13, 10
           BYTE "  G:::::GGGGGGGG::::G            A:::::::A            M:::::::::M         M:::::::::MEE::::::EEEEEEEEE::::E     O:::::::OOO:::::::OV::::::V           V::::::VEE::::::EEEEEEEEE::::ERR:::::R     R:::::R", 13, 10
           BYTE " G:::::G       GGGGGG           A:::::::::A           M::::::::::M       M::::::::::M  E:::::E       EEEEEE     O::::::O   O::::::O V:::::V           V:::::V   E:::::E       EEEEEE  R::::R     R:::::R", 13, 10
           BYTE "G:::::G                        A:::::A:::::A          M:::::::::::M     M:::::::::::M  E:::::E                  O:::::O     O:::::O  V:::::V         V:::::V    E:::::E               R::::R     R:::::R", 13, 10
           BYTE "G:::::G                       A:::::A A:::::A         M:::::::M::::M   M::::M:::::::M  E::::::EEEEEEEEEE        O:::::O     O:::::O   V:::::V       V:::::V     E::::::EEEEEEEEEE     R::::RRRRRR:::::R ", 13, 10
           BYTE "G:::::G    GGGGGGGGGG        A:::::A   A:::::A        M::::::M M::::M M::::M M::::::M  E:::::::::::::::E        O:::::O     O:::::O    V:::::V     V:::::V      E:::::::::::::::E     R:::::::::::::RR  ", 13, 10
           BYTE "G:::::G    G::::::::G       A:::::A     A:::::A       M::::::M  M::::M::::M  M::::::M  E:::::::::::::::E        O:::::O     O:::::O     V:::::V   V:::::V       E:::::::::::::::E     R::::RRRRRR:::::R ", 13, 10
           BYTE "G:::::G    GGGGG::::G      A:::::AAAAAAAAA:::::A      M::::::M   M:::::::M   M::::::M  E::::::EEEEEEEEEE        O:::::O     O:::::O      V:::::V V:::::V        E::::::EEEEEEEEEE     R::::R     R:::::R", 13, 10
           BYTE "G:::::G        G::::G     A:::::::::::::::::::::A     M::::::M    M:::::M    M::::::M  E:::::E                  O:::::O     O:::::O       V:::::V:::::V         E:::::E               R::::R     R:::::R", 13, 10
           BYTE " G:::::G       G::::G    A:::::AAAAAAAAAAAAA:::::A    M::::::M     MMMMM     M::::::M  E:::::E       EEEEEE     O::::::O   O::::::O        V:::::::::V          E:::::E       EEEEEE  R::::R     R:::::R", 13, 10
           BYTE "  G:::::GGGGGGGG::::G   A:::::A             A:::::A   M::::::M               M::::::MEE::::::EEEEEEEE:::::E     O:::::::OOO:::::::O         V:::::::V         EE::::::EEEEEEEE:::::ERR:::::R     R:::::R", 13, 10
           BYTE "   GG:::::::::::::::G  A:::::A               A:::::A  M::::::M               M::::::ME::::::::::::::::::::E      OO:::::::::::::OO           V:::::V          E::::::::::::::::::::ER::::::R     R:::::R", 13, 10
           BYTE "     GGG::::::GGG:::G A:::::A                 A:::::A M::::::M               M::::::ME::::::::::::::::::::E        OO:::::::::OO              V:::V           E::::::::::::::::::::ER::::::R     R:::::R", 13, 10
           BYTE "        GGGGGG   GGGGAAAAAAA                   AAAAAAAMMMMMMMM               MMMMMMMMEEEEEEEEEEEEEEEEEEEEEE          OOOOOOOOO                 VVV            EEEEEEEEEEEEEEEEEEEEEERRRRRRRR     RRRRRRR", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 13, 10
           BYTE "                                                                                                                                                                                                        ", 0

; Temporary variables for calculations
tempRow DWORD 0
tempCol DWORD 0
tempPos DWORD 0
tempDir DWORD 0

; Grid cell state storage for ghost movement
cellState BYTE 0       ; To store the original state of a cell before ghost moves to it

; Pause screen art
pauseArt BYTE " .----------------. .----------------. .----------------. .----------------. .----------------. .----------------. ", 13, 10
        BYTE "| .--------------. | .--------------. | .--------------. | .--------------. | .--------------. | .--------------. |", 13, 10
        BYTE "| |   ______     | | |      __      | | | _____  _____ | | |    _______   | | |  _________   | | |  ________    | |", 13, 10
        BYTE "| |  |_   __ \   | | |     /  \     | | ||_   _||_   _|| | |   /  ___  |  | | | |_   ___  |  | | | |_   ___ `.  | |", 13, 10
        BYTE "| |    | |__) |  | | |    / /\ \    | | |  | |    | |  | | |  |  (__ \_|  | | |   | |_  \_|  | | |   | |   `. \ | |", 13, 10
        BYTE "| |    |  ___/   | | |   / ____ \   | | |  | '    ' |  | | |   '.___`-.   | | |   |  _|  _   | | |   | |    | | | |", 13, 10
        BYTE "| |   _| |_      | | | _/ /    \ \_ | | |   \ `--' /   | | |  |`\____) |  | | |  _| |___/ |  | | |  _| |___.' / | |", 13, 10
        BYTE "| |  |_____|     | | ||____|  |____|| | |    `.__.'    | | |  |_______.'  | | | |_________|  | | | |________.'  | |", 13, 10
        BYTE "| |              | | |              | | |              | | |              | | |              | | |              | |", 13, 10
        BYTE "| '--------------' | '--------------' | '--------------' | '--------------' | '--------------' | '--------------' |", 13, 10
        BYTE " '----------------' '----------------' '----------------' '----------------' '----------------' '----------------' ", 0

instructionsArt BYTE "    _            __                  __  _                 ", 13, 10
                BYTE "   (_____  _____/ /________  _______/ /_(_____  ____  _____", 13, 10
                BYTE "  / / __ \/ ___/ __/ ___/ / / / ___/ __/ / __ \/ __ \/ ___/", 13, 10
                BYTE " / / / / (__  / /_/ /  / /_/ / /__/ /_/ / /_/ / / / (__  ) ", 13, 10
                BYTE "/_/_/ /_/____/\__/_/   \__,_/\___/\__/_/\____/_/ /_/____/  ", 13, 10
                BYTE "                                                           ", 0

; Game instructions
instruction1 BYTE "How to Play:", 0
instruction2 BYTE "- Use WASD keys to move Pacman", 0
instruction3 BYTE "- Collect dots to earn points (2 points each)", 0
instruction4 BYTE "- Avoid ghosts - they will chase you!", 0
instruction5 BYTE "- You have 3 lives - getting caught by a ghost costs 1 life", 0
instruction6 BYTE "- Press P to pause/unpause the game", 0
instruction7 BYTE "- Press Q to quit", 0
instruction8 BYTE "How to Win:", 0
instruction9 BYTE "- Collect all dots to complete the level", 0
instruction10 BYTE "- Try to get the highest score possible!", 0

; Add KEY_P to existing key definitions
KEY_P DWORD 112        ; 'p' for pause

; Add isPaused flag to game state variables
isPaused BYTE 0        ; 0 = not paused, 1 = paused

; Level selection ASCII art
level1Art BYTE " _                     _   __  ", 13, 10
         BYTE "| |                   | | /  | ", 13, 10
         BYTE "| |  ___ __   __  ___ | | `| | ", 13, 10
         BYTE "| | / _ \\ \ / / / _ \| |  | | ", 13, 10
         BYTE "| ||  __/ \ V / |  __/| | _| |_", 13, 10
         BYTE "|_| \___|  \_/   \___||_| \___/", 13, 10
         BYTE "                               ", 13, 10
         BYTE "                               ", 0

level2Art BYTE " _                     _   _____ ", 13, 10
         BYTE "| |                   | | / __  \", 13, 10
         BYTE "| |  ___ __   __  ___ | | `' / /'", 13, 10
         BYTE "| | / _ \\ \ / / / _ \| |   / /  ", 13, 10
         BYTE "| ||  __/ \ V / |  __/| | ./ /___", 13, 10
         BYTE "|_| \___|  \_/   \___||_| \_____/", 13, 10
         BYTE "                                 ", 13, 10
         BYTE "                                 ", 0

level3Art BYTE " _                     _   _____ ", 13, 10
         BYTE "| |                   | | |____ |", 13, 10
         BYTE "| |  ___ __   __  ___ | |     / /", 13, 10
         BYTE "| | / _ \\ \ / / / _ \| |   \ \", 13, 10
         BYTE "| ||  __/ \ V / |  __/| | .___/ /", 13, 10
         BYTE "|_| \___|  \_/   \___||_| \____/ ", 13, 10
         BYTE "                                 ", 13, 10
         BYTE "                                 ", 0

; Selection arrow
selectionArrow BYTE "->", 0
selectedLevel BYTE 1    ; Currently selected level (1-3)
levelSelectMsg BYTE "Use W/S to move, Spacebar to select", 0

; Add key definitions for level selection
KEY_W_UP DWORD 119    ; 'w'
KEY_S_DOWN DWORD 115  ; 's'
KEY_SPACE DWORD 32    ; spacebar

; Add last direction variable
lastDirection DWORD 0  ; 0=none, 1=up, 2=right, 3=down, 4=left
MOVE_DELAY DWORD 100  ; Delay in milliseconds between moves (reduced from 250)

; Level 2 specific variables
fruitPos DWORD 0
fruitActive BYTE 0
fruitTimer DWORD 0
fruitPoints DWORD 20

; Wall sliding variables
wallDirection DWORD 1       ; 1 = right, 0 = left
wallSlideTimer DWORD 0
wallSlideDelay DWORD 50    ; Delay between wall movements in ms (reduced from 100)

; Wall colors for each level
wallColorLevel1 WORD ?      ; Will store the color attribute for blue background
wallColorLevel2 WORD ?      ; Will store the color attribute for red background
wallColorLevel3 WORD ?      ; Will store the color attribute for green background

; Level 3 specific variables (no vertical sliding columns)

; Add these messages to the .data section
powerUpMsg BYTE "POWER-UP ACTIVE: ", 0
normalMsg BYTE "POWER-UP: NONE   ", 0

; Add debug messages to data section
fruitSpawnMsg BYTE "FRUIT SPAWNED! Timer: ", 0
fruitInitMsg BYTE "FRUIT INITIALIZED at position: ", 0

; Add debug message
fruitEatenMsg BYTE "FRUIT EATEN! POWER-UP ACTIVATED!", 0

; Add more debug/status messages
fruitStatusMsg BYTE "FRUIT ACTIVE AT: ", 0

; Also add this message to data section
fruitTimerMsg BYTE "Fruit Timer: ", 0

; Add this message to data section
fruitSetupMsg BYTE "FRUIT SETUP FOR LEVEL 2 AT: ", 0

; Level 3 specific variables
teleportPadChar BYTE 'T', 0   ; Teleport pad character
teleport1Pos DWORD 0          ; Position of first teleport pad
teleport2Pos DWORD 0          ; Position of second teleport pad
ghost6Pos DWORD 0             ; Cyan ghost position (level 3 only)
ghost7Pos DWORD 0             ; Magenta ghost position (level 3 only)
level3GhostDelay DWORD 50     ; Faster ghost movement delay for level 3 (half of normal)

; Ghost colors for each ghost
ghost1Color WORD ?      ; Will store red
ghost2Color WORD ?      ; Will store brown
ghost3Color WORD ?      ; Will store green
ghost4Color WORD ?      ; Will store orange
ghost5Color WORD ?      ; Will store pink (for level 2 only)
ghost6Color WORD ?      ; Will store cyan (for level 3 only)
ghost7Color WORD ?      ; Will store magenta (for level 3 only)

; File handling for highscores
highscoresFile BYTE "highscores.txt", 0     ; Filename for highscores
fileHandle HANDLE ?                          ; File handle
bytesWritten DWORD ?                         ; Number of bytes written
scoreBuffer BYTE 256 DUP(0)                  ; Buffer for formatting score entry
commaChar BYTE ",", 0                        ; Comma character
newlineChars BYTE 13, 10                     ; Carriage return and line feed

; MCI command strings for playing MP3s
mciOpenCmd BYTE "open ", 256 DUP(0)          ; Buffer for MCI open command
mciPlayCmd BYTE "play ", 256 DUP(0)          ; Buffer for MCI play command
mciCloseCmd BYTE "close ", 256 DUP(0)        ; Buffer for MCI close command
mciReturn BYTE 128 DUP(0)                    ; Buffer for MCI return values
mciAlias BYTE "pacmanmp3", 0                 ; Alias for MCI device

; Sound file paths - updated to point to the correct MP3 file locations
pelletSoundFile BYTE "pellet.mp3", 0
teleportSoundFile BYTE "teleport.mp3", 0
deathSoundFile BYTE "death.mp3", 0
gameOverSoundFile BYTE "gameover.mp3", 0

; Sound frequencies and durations (fallback for Beep if MP3 files not available)
pelletSoundFreq DWORD 800                    ; Frequency for pellet eaten sound (Hz)
pelletSoundDur DWORD 30                      ; Duration for pellet eaten sound (ms)
teleportSoundFreq DWORD 400                  ; Frequency for teleport sound (Hz)
teleportSoundDur DWORD 200                   ; Duration for teleport sound (ms)
deathSoundFreq DWORD 200                     ; Frequency for death sound (Hz)
deathSoundDur DWORD 500                      ; Duration for death sound (ms)
gameOverSoundFreq DWORD 150                  ; Frequency for game over sound (Hz)
gameOverSoundDur DWORD 1000                  ; Duration for game over sound (ms)

; Additional variables for sound effects

.code
; Helper procedure to play MP3 sound files
PlaySoundFile PROC,
    pFileName:PTR BYTE,  ; Pointer to filename string
    useBeep:DWORD,       ; Frequency to use if falling back to Beep
    beepDuration:DWORD   ; Duration to use if falling back to Beep

    pushad                ; Save all registers

    ; Try to play MP3 file first

    ; Clear command buffers
    mov edi, OFFSET mciOpenCmd
    mov eax, 0
    mov ecx, 256
    rep stosb

    mov edi, OFFSET mciPlayCmd
    mov eax, 0
    mov ecx, 256
    rep stosb

    mov edi, OFFSET mciCloseCmd
    mov eax, 0
    mov ecx, 128
    rep stosb

    ; Format "open filename type mpegvideo alias pacmanmp3" command
    mov edi, OFFSET mciOpenCmd
    mov BYTE PTR [edi], 'o'
    mov BYTE PTR [edi+1], 'p'
    mov BYTE PTR [edi+2], 'e'
    mov BYTE PTR [edi+3], 'n'
    mov BYTE PTR [edi+4], ' '
    add edi, 5          ; Skip over "open "

    ; Copy filename to command
    mov esi, pFileName  ; Point to filename

CopyFilename:
    mov al, [esi]
    cmp al, 0
    je DoneCopyFilename
    mov [edi], al
    inc esi
    inc edi
    jmp CopyFilename

DoneCopyFilename:
    ; Append " type mpegvideo alias pacmanmp3" to command
    mov BYTE PTR [edi], ' '
    inc edi
    mov BYTE PTR [edi], 't'
    mov BYTE PTR [edi+1], 'y'
    mov BYTE PTR [edi+2], 'p'
    mov BYTE PTR [edi+3], 'e'
    mov BYTE PTR [edi+4], ' '
    mov BYTE PTR [edi+5], 'm'
    mov BYTE PTR [edi+6], 'p'
    mov BYTE PTR [edi+7], 'e'
    mov BYTE PTR [edi+8], 'g'
    mov BYTE PTR [edi+9], 'v'
    mov BYTE PTR [edi+10], 'i'
    mov BYTE PTR [edi+11], 'd'
    mov BYTE PTR [edi+12], 'e'
    mov BYTE PTR [edi+13], 'o'
    mov BYTE PTR [edi+14], ' '
    mov BYTE PTR [edi+15], 'a'
    mov BYTE PTR [edi+16], 'l'
    mov BYTE PTR [edi+17], 'i'
    mov BYTE PTR [edi+18], 'a'
    mov BYTE PTR [edi+19], 's'
    mov BYTE PTR [edi+20], ' '
    mov BYTE PTR [edi+21], 'p'
    mov BYTE PTR [edi+22], 'a'
    mov BYTE PTR [edi+23], 'c'
    mov BYTE PTR [edi+24], 'm'
    mov BYTE PTR [edi+25], 'a'
    mov BYTE PTR [edi+26], 'n'
    mov BYTE PTR [edi+27], 'm'
    mov BYTE PTR [edi+28], 'p'
    mov BYTE PTR [edi+29], '3'
    mov BYTE PTR [edi+30], 0

    ; Send "open" command to MCI
    INVOKE mciSendStringA, OFFSET mciOpenCmd, OFFSET mciReturn, 128, 0

    ; Check if open succeeded
    cmp eax, 0
    jne UseFallbackBeep ; If error, fall back to Beep

    ; Format "play pacmanmp3" command
    mov edi, OFFSET mciPlayCmd
    mov BYTE PTR [edi], 'p'
    mov BYTE PTR [edi+1], 'l'
    mov BYTE PTR [edi+2], 'a'
    mov BYTE PTR [edi+3], 'y'
    mov BYTE PTR [edi+4], ' '
    mov BYTE PTR [edi+5], 'p'
    mov BYTE PTR [edi+6], 'a'
    mov BYTE PTR [edi+7], 'c'
    mov BYTE PTR [edi+8], 'm'
    mov BYTE PTR [edi+9], 'a'
    mov BYTE PTR [edi+10], 'n'
    mov BYTE PTR [edi+11], 'm'
    mov BYTE PTR [edi+12], 'p'
    mov BYTE PTR [edi+13], '3'
    mov BYTE PTR [edi+14], 0

    ; Send "play" command to MCI
    INVOKE mciSendStringA, OFFSET mciPlayCmd, OFFSET mciReturn, 128, 0

    ; Wait a bit for sound to play
    mov eax, beepDuration
    call Delay

    ; Format "close pacmanmp3" command
    mov edi, OFFSET mciCloseCmd
    mov BYTE PTR [edi], 'c'
    mov BYTE PTR [edi+1], 'l'
    mov BYTE PTR [edi+2], 'o'
    mov BYTE PTR [edi+3], 's'
    mov BYTE PTR [edi+4], 'e'
    mov BYTE PTR [edi+5], ' '
    mov BYTE PTR [edi+6], 'p'
    mov BYTE PTR [edi+7], 'a'
    mov BYTE PTR [edi+8], 'c'
    mov BYTE PTR [edi+9], 'm'
    mov BYTE PTR [edi+10], 'a'
    mov BYTE PTR [edi+11], 'n'
    mov BYTE PTR [edi+12], 'm'
    mov BYTE PTR [edi+13], 'p'
    mov BYTE PTR [edi+14], '3'
    mov BYTE PTR [edi+15], 0

    ; Send "close" command to MCI
    INVOKE mciSendStringA, OFFSET mciCloseCmd, OFFSET mciReturn, 128, 0

    jmp DonePlayingSound

UseFallbackBeep:
    ; Fall back to Beep function if MCI fails
    INVOKE Beep, useBeep, beepDuration

DonePlayingSound:
    popad                ; Restore all registers
    ret
PlaySoundFile ENDP

main PROC
    ; Get the console handle for screen manipulation
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov consoleHandle, eax

    ; Hide the cursor
    mov cursorInfo.dwSize, 1
    mov cursorInfo.bVisible, 0
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo

    ; Show welcome screen and get player info
    call ShowWelcomeScreen

    ; Initialize and start the game
    call InitializeGame
    call GameLoop
    call CleanupGame
    exit
main ENDP

ShowWelcomeScreen PROC
    ; Set color to black text on white background
    mov eax, black + (white * 16)    ; black text (0) on white background (15 * 16)
    call SetTextColor

    ; Clear screen
    call Clrscr

    ; Show cursor for name input
    mov cursorInfo.bVisible, 1
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo

    ; Display welcome art
    mov edx, OFFSET welcomeArt
    call WriteString
    call Crlf
    call Crlf

    ; Get player name
    mov edx, OFFSET namePrompt
    call WriteString
    mov edx, OFFSET playerName
    mov ecx, 31         ; Maximum 31 characters + null terminator
    call ReadString
    call Crlf

    ; Hide cursor for level selection
    mov cursorInfo.bVisible, 0
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo

    ; Show level selection screen
    call ShowLevelSelection

    ret
ShowWelcomeScreen ENDP

ShowLevelSelection PROC
    ; Set color to black text on white background
    mov eax, black + (white * 16)    ; black text (0) on white background (15 * 16)
    call SetTextColor

    ; Clear screen
    call Clrscr

LevelSelectLoop:
    ; Set color to black text on white background again after each clear
    mov eax, black + (white * 16)    ; black text (0) on white background (15 * 16)
    call SetTextColor

    ; Clear screen each time we redraw
    call Clrscr

    ; Display instruction
    mov dl, 0
    mov dh, 0
    call Gotoxy
    mov edx, OFFSET levelSelectMsg
    call WriteString
    call Crlf
    call Crlf

    ; Display Level 1 with arrow if selected
    mov dl, 0
    mov dh, 2
    call Gotoxy
    cmp selectedLevel, 1
    jne SkipArrow1
    mov edx, OFFSET selectionArrow
    call WriteString
SkipArrow1:
    mov edx, OFFSET level1Art
    call WriteString
    call Crlf

    ; Display Level 2 with arrow if selected
    mov dl, 0
    mov dh, 12
    call Gotoxy
    cmp selectedLevel, 2
    jne SkipArrow2
    mov edx, OFFSET selectionArrow
    call WriteString
SkipArrow2:
    mov edx, OFFSET level2Art
    call WriteString
    call Crlf

    ; Display Level 3 with arrow if selected
    mov dl, 0
    mov dh, 22
    call Gotoxy
    cmp selectedLevel, 3
    jne SkipArrow3
    mov edx, OFFSET selectionArrow
    call WriteString
SkipArrow3:
    mov edx, OFFSET level3Art
    call WriteString

    ; Get input
    call ReadChar

    ; Check input
    movzx ebx, al

    ; Check for W (up)
    cmp ebx, KEY_W_UP
    jne NotW
    cmp selectedLevel, 1
    je LevelSelectLoop    ; Already at top
    dec selectedLevel
    jmp LevelSelectLoop
NotW:

    ; Check for S (down)
    cmp ebx, KEY_S_DOWN
    jne NotS
    cmp selectedLevel, 3
    je LevelSelectLoop    ; Already at bottom
    inc selectedLevel
    jmp LevelSelectLoop
NotS:

    ; Check for spacebar (select)
    cmp ebx, KEY_SPACE
    jne LevelSelectLoop

    ; Allow selection of Level 1, 2, or 3
    cmp selectedLevel, 1
    je LevelSelected
    cmp selectedLevel, 2
    je LevelSelected
    cmp selectedLevel, 3
    je LevelSelected
    jmp LevelSelectLoop

LevelSelected:
    ; Store selected level and return
    mov al, selectedLevel
    mov currentLevel, al

    ; Wait a moment before continuing
    mov eax, 1000    ; 1 second
    call Delay

    ret
ShowLevelSelection ENDP

; Initializes the game state
InitializeGame PROC
    ; Initialize console to enable keyboard input with white background and black text
    mov eax, black + (white * 16)    ; black text (0) on white background (15 * 16)
    call SetTextColor
    call Clrscr

    ; Initialize random seed
    call Randomize

    ; Initialize ghost colors
    mov ghost1Color, red + (white * 16)        ; Red ghost
    mov ghost2Color, brown + (white * 16)      ; Brown ghost
    mov ghost3Color, green + (white * 16)      ; Green ghost
    mov ghost4Color, 6 + (white * 16)          ; Orange/yellow ghost (color code 6)
    mov ghost5Color, 13 + (white * 16)         ; Pink/magenta ghost (color code 13)
    mov ghost6Color, cyan + (white * 16)       ; Cyan ghost (for level 3)
    mov ghost7Color, magenta + (white * 16)    ; Magenta ghost (for level 3)

    ; Initialize the grid with dots
    mov ecx, 2048      ; 32 * 64 = 2048 cells
    mov esi, 0

InitializeGridLoop:
    mov al, dotChar
    mov grid[esi], al
    inc esi
    loop InitializeGridLoop

    ; Add walls around the border
    call AddBorderWalls

    ; Initialize wall colors and features for all levels

    ; For Level 1, initialize the wall color (blue background)
    mov wallColorLevel1, blue * 16 + white   ; Blue background with white text

    ; For Level 2, initialize the wall color (red background)
    mov wallColorLevel2, red * 16 + white    ; Red background with white text

    ; For Level 3, initialize the wall color (green background)
    mov wallColorLevel3, green * 16 + white  ; Green background with white text

    ; Reset timers for all levels
    mov fruitTimer, 0                        ; Reset fruit timer
    mov wallSlideTimer, 0                    ; Reset wall slide timer

    ; Reset game state
    mov gameEndReason, 0                     ; Reset game end reason


    ; Level-specific initializations
    cmp currentLevel, 1
    je InitLevel1
    cmp currentLevel, 2
    je InitLevel2
    cmp currentLevel, 3
    je InitLevel3
    jmp NotLevel3Init                        ; Default case

InitLevel1:
    ; Level 1 specific initialization
    mov fruitActive, 0                       ; No fruit initially in level 1
    jmp NotLevel3Init

InitLevel2:
    ; Level 2 specific initialization
    mov fruitActive, 1                       ; Activate fruit initially

    ; Place initial fruit at fixed position
    mov eax, 10                              ; Row 10
    mul gridWidth
    add eax, 30                              ; Column 30
    mov fruitPos, eax
    mov esi, eax
    mov al, fruitChar                        ; Set as fruit char
    mov grid[esi], al
    jmp NotLevel3Init

InitLevel3:
    ; Level 3 specific initialization
    mov fruitActive, 1                       ; Activate fruit initially

    ; Place initial fruit at fixed position
    mov eax, 15                              ; Row 15
    mul gridWidth
    add eax, 45                              ; Column 45
    mov fruitPos, eax
    mov esi, eax
    mov al, fruitChar                        ; Set as fruit char
    mov grid[esi], al

CheckLevel3Init:
    ; For Level 3, initialize teleport pads and obstacles
    cmp currentLevel, 3
    jne NotLevel3Init

    ; Place teleport pad 1 (top middle)
    mov eax, 2                               ; Row 2 (closer to top)
    mul gridWidth
    add eax, 32                              ; Column 32 (middle)
    mov teleport1Pos, eax
    mov esi, eax
    mov al, teleportPadChar                  ; Set as teleport pad
    mov grid[esi], al

    ; Place teleport pad 2 (bottom middle)
    mov eax, 26                              ; Row 26
    mul gridWidth
    add eax, 32                              ; Column 32 (middle)
    mov teleport2Pos, eax
    mov esi, eax
    mov al, teleportPadChar                  ; Set as teleport pad
    mov grid[esi], al

    ; Add hardcoded obstacles for level 3 (similar to original Pacman)
    ; These are static and won't move vertically

    ; Top-left T-shaped obstacle
    mov eax, 5          ; Row 5
    mul gridWidth
    add eax, 10         ; Column 10
    mov esi, eax
    mov ecx, 6          ; Width of horizontal part
TopLeftHorizontal:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop TopLeftHorizontal

    ; Vertical part of top-left T
    mov eax, 6          ; Row 6
    mul gridWidth
    add eax, 12         ; Column 12 (middle of horizontal part)
    mov esi, eax
    mov ecx, 4          ; Height of vertical part
TopLeftVertical:
    mov al, wallChar
    mov grid[esi], al
    add esi, gridWidth
    loop TopLeftVertical

    ; Top-right T-shaped obstacle
    mov eax, 5          ; Row 5
    mul gridWidth
    add eax, 48         ; Column 48
    mov esi, eax
    mov ecx, 6          ; Width of horizontal part
TopRightHorizontal:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop TopRightHorizontal

    ; Vertical part of top-right T
    mov eax, 6          ; Row 6
    mul gridWidth
    add eax, 50         ; Column 50 (middle of horizontal part)
    mov esi, eax
    mov ecx, 4          ; Height of vertical part
TopRightVertical:
    mov al, wallChar
    mov grid[esi], al
    add esi, gridWidth
    loop TopRightVertical

    ; Removed the middle-left and middle-right L-shaped obstacles as requested

    ; Bottom-left box obstacle
    mov eax, 24         ; Row 24
    mul gridWidth
    add eax, 10         ; Column 10
    mov esi, eax

    ; Draw a 4x4 box
    mov ecx, 4          ; Height of box
BoxLeftLoop:
    push ecx
    push esi

    mov ecx, 4          ; Width of box
BoxLeftInnerLoop:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop BoxLeftInnerLoop

    pop esi
    add esi, gridWidth  ; Move to next row
    pop ecx
    loop BoxLeftLoop

    ; Bottom-right box obstacle
    mov eax, 24         ; Row 24
    mul gridWidth
    add eax, 50         ; Column 50
    mov esi, eax

    ; Draw a 4x4 box
    mov ecx, 4          ; Height of box
BoxRightLoop:
    push ecx
    push esi

    mov ecx, 4          ; Width of box
BoxRightInnerLoop:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop BoxRightInnerLoop

    pop esi
    add esi, gridWidth  ; Move to next row
    pop ecx
    loop BoxRightLoop

    ; Center ghost box (similar to original Pacman but with open bottom)
    mov eax, 14         ; Row 14
    mul gridWidth
    add eax, 27         ; Column 27
    mov esi, eax

    ; Draw top of ghost box
    mov ecx, 10         ; Width of box
GhostBoxTop:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop GhostBoxTop

    ; Draw sides of ghost box (but not the bottom)
    mov ecx, 4          ; Height of sides
GhostBoxSides:
    ; Left side
    mov eax, 15         ; Starting row (after top)
    add eax, ecx        ; Current row
    dec eax             ; Adjust for 0-based index
    mul gridWidth
    add eax, 27         ; Left column
    mov esi, eax
    mov al, wallChar
    mov grid[esi], al

    ; Right side
    mov eax, 15         ; Starting row (after top)
    add eax, ecx        ; Current row
    dec eax             ; Adjust for 0-based index
    mul gridWidth
    add eax, 36         ; Right column
    mov esi, eax
    mov al, wallChar
    mov grid[esi], al

    loop GhostBoxSides

    ; Bottom of ghost box removed as requested

NotLevel3Init:

    ; Add interior walls
    call AddInteriorWalls

    ; Initialize Pacman position (middle of grid)
    mov eax, 15        ; Middle row (32/2 - 1)
    mul gridWidth
    add eax, 32        ; Middle column (64/2)
    mov pacmanPos, eax
    mov esi, eax
    mov al, pacmanChar
    mov grid[esi], al

    ; Initialize Ghost positions in different corners
    ; Ghost 1 - Top left area (red)
    mov eax, 3
    mul gridWidth
    add eax, 3
    mov ghost1Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al

    ; Ghost 2 - Top right area (brown)
    mov eax, 3
    mul gridWidth
    add eax, 60        ; gridWidth - 4
    mov ghost2Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al

    ; Ghost 3 - Bottom left area (green)
    mov eax, 28        ; gridHeight - 4
    mul gridWidth
    add eax, 3
    mov ghost3Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al

    ; Ghost 4 - Bottom right area (orange)
    mov eax, 28        ; gridHeight - 4
    mul gridWidth
    add eax, 60        ; gridWidth - 4
    mov ghost4Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al

    ; Ghost 5 - Only for Level 2 (pink)
    cmp currentLevel, 2
    jne CheckLevel3Ghosts
    mov eax, 15        ; Middle row
    mul gridWidth
    add eax, 15        ; Left of center
    mov ghost5Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al
    jmp SkipExtraGhosts

CheckLevel3Ghosts:
    ; Ghosts 6 and 7 - Only for Level 3 (cyan and magenta)
    cmp currentLevel, 3
    jne SkipExtraGhosts

    ; Ghost 6 - Cyan ghost (top middle)
    mov eax, 8         ; Row 8
    mul gridWidth
    add eax, 32        ; Middle column
    mov ghost6Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al

    ; Ghost 7 - Magenta ghost (bottom middle)
    mov eax, 23        ; Row 23
    mul gridWidth
    add eax, 32        ; Middle column
    mov ghost7Pos, eax
    mov esi, eax
    mov al, ghostChar
    mov grid[esi], al

SkipExtraGhosts:

    ; Count the initial number of dots in the grid
    call CountRemainingDots

    ret
InitializeGame ENDP

; Adds walls around the border of the grid
AddBorderWalls PROC
    ; Top wall
    mov ecx, 64        ; gridWidth
    mov esi, 0
TopWallLoop:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop TopWallLoop

    ; Bottom wall
    mov ecx, 64        ; gridWidth
    mov eax, 31        ; gridHeight - 1
    mul gridWidth
    mov esi, eax
BottomWallLoop:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop BottomWallLoop

    ; Left wall
    mov ecx, 32        ; gridHeight
    mov esi, 0
LeftWallLoop:
    mov al, wallChar
    mov grid[esi], al
    add esi, 64        ; gridWidth
    loop LeftWallLoop

    ; Right wall
    mov ecx, 32        ; gridHeight
    mov esi, 63        ; gridWidth - 1
RightWallLoop:
    mov al, wallChar
    mov grid[esi], al
    add esi, 64        ; gridWidth
    loop RightWallLoop

    ret
AddBorderWalls ENDP

; Adds interior walls as specified
AddInteriorWalls PROC
    ; Row 1: 2 walls of 8 units each (evenly spaced)
    mov eax, 6         ; First row of walls
    mul gridWidth
    add eax, 16        ; Start position for first wall
    mov esi, eax
    mov ecx, 8         ; Length of wall
Row1Wall1:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row1Wall1

    mov eax, 6         ; Same row
    mul gridWidth
    add eax, 40        ; Start position for second wall
    mov esi, eax
    mov ecx, 8         ; Length of wall
Row1Wall2:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row1Wall2

    ; Row 2: 5 walls of 8 units each (evenly spaced)
    mov eax, 12        ; Second row
    mul gridWidth
    add eax, 4         ; First wall
    mov esi, eax
    mov ecx, 8
Row2Wall1:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row2Wall1

    mov eax, 12
    mul gridWidth
    add eax, 16        ; Second wall
    mov esi, eax
    mov ecx, 8
Row2Wall2:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row2Wall2

    mov eax, 12
    mul gridWidth
    add eax, 28        ; Third wall (middle)
    mov esi, eax
    mov ecx, 8
Row2Wall3:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row2Wall3

    mov eax, 12
    mul gridWidth
    add eax, 40        ; Fourth wall
    mov esi, eax
    mov ecx, 8
Row2Wall4:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row2Wall4

    mov eax, 12
    mul gridWidth
    add eax, 52        ; Fifth wall
    mov esi, eax
    mov ecx, 8
Row2Wall5:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row2Wall5

    ; Row 3: 3 walls of 8 units each (evenly spaced)
    mov eax, 18        ; Third row
    mul gridWidth
    add eax, 12        ; First wall
    mov esi, eax
    mov ecx, 8
Row3Wall1:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row3Wall1

    mov eax, 18
    mul gridWidth
    add eax, 28        ; Second wall (middle)
    mov esi, eax
    mov ecx, 8
Row3Wall2:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row3Wall2

    mov eax, 18
    mul gridWidth
    add eax, 44        ; Third wall
    mov esi, eax
    mov ecx, 8
Row3Wall3:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row3Wall3

    ; Row 4: 5 walls of 8 units each (evenly spaced) - same pattern as row 2
    mov eax, 24        ; Fourth row
    mul gridWidth
    add eax, 4         ; First wall
    mov esi, eax
    mov ecx, 8
Row4Wall1:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row4Wall1

    mov eax, 24
    mul gridWidth
    add eax, 16        ; Second wall
    mov esi, eax
    mov ecx, 8
Row4Wall2:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row4Wall2

    mov eax, 24
    mul gridWidth
    add eax, 28        ; Third wall (middle)
    mov esi, eax
    mov ecx, 8
Row4Wall3:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row4Wall3

    mov eax, 24
    mul gridWidth
    add eax, 40        ; Fourth wall
    mov esi, eax
    mov ecx, 8
Row4Wall4:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row4Wall4

    mov eax, 24
    mul gridWidth
    add eax, 52        ; Fifth wall
    mov esi, eax
    mov ecx, 8
Row4Wall5:
    mov al, wallChar
    mov grid[esi], al
    inc esi
    loop Row4Wall5

    ret
AddInteriorWalls ENDP

; Main game loop
GameLoop PROC
    ; Draw the initial grid
    call DrawGrid

    ; Display instructions
    mov dl, 0
    mov dh, 34
    call Gotoxy
    mov edx, OFFSET msgQuit
    call WriteString

    ; Initialize last direction to none
    mov lastDirection, 0

GameLoopStart:
    ; Update power-up timer if active
    cmp powerUpActive, 1
    jne SkipPowerUpTimer
    inc powerUpTimer
    mov eax, powerUpTimer
    cmp eax, powerUpDuration
    jl SkipPowerUpTimer
    ; Power-up expired
    mov powerUpActive, 0
    mov powerUpTimer, 0
SkipPowerUpTimer:

    ; Check for keyboard input (non-blocking)
    call ReadKey
    jz NoInput        ; If no key pressed, jump to movement processing

    ; Process the key that was pressed
    movzx ebx, al

    ; Check for pause first
    cmp ebx, KEY_P
    jne NotPause
    call TogglePause
    jmp GameLoopStart
NotPause:

    ; If paused, ignore other inputs except P
    cmp isPaused, 1
    je GameLoopStart

    ; Process direction inputs
    cmp ebx, KEY_W
    jne NotW
    mov lastDirection, 1    ; Up
    jmp NoInput
NotW:
    cmp ebx, KEY_D
    jne NotD
    mov lastDirection, 2    ; Right
    jmp NoInput
NotD:
    cmp ebx, KEY_S
    jne NotS
    mov lastDirection, 3    ; Down
    jmp NoInput
NotS:
    cmp ebx, KEY_A
    jne NotA
    mov lastDirection, 4    ; Left
    jmp NoInput
NotA:
    cmp ebx, KEY_Q
    je QuitGame

NoInput:
    ; Update level-specific features
    cmp currentLevel, 1
    je SkipLevelUpdates        ; Level 1 has no special updates

    cmp currentLevel, 2
    je UpdateLevel2

    cmp currentLevel, 3
    je UpdateLevel3

    jmp SkipLevelUpdates       ; Default case

UpdateLevel2:
    call UpdateLevel2Features
    jmp SkipLevelUpdates

UpdateLevel3:
    call UpdateLevel3Features

SkipLevelUpdates:

    ; Add delay between moves
    mov eax, MOVE_DELAY
    call Delay

    ; If paused, skip movement
    cmp isPaused, 1
    je GameLoopStart

    ; Process movement based on last direction
    mov eax, lastDirection
    cmp eax, 0
    je SkipMovement    ; No movement if no direction set
    cmp eax, 1
    je ProcessMoveUp
    cmp eax, 2
    je ProcessMoveRight
    cmp eax, 3
    je ProcessMoveDown
    cmp eax, 4
    je ProcessMoveLeft
    jmp SkipMovement

ProcessMoveUp:
    ; Calculate new position (current - gridWidth)
    mov ebx, pacmanPos
    sub ebx, gridWidth
    ; Check if valid move
    movzx eax, grid[ebx]
    cmp al, wallChar
    je CheckLevel2Wall
    ; Check for ghost collision
    cmp al, ghostChar
    je GhostCollision

    ; Check for fruit - explicit fruit check
    cmp al, fruitChar
    jne CheckTeleportUp

    ; Collect fruit
    mov eax, fruitPoints    ; Move fruitPoints to register first
    add score, eax          ; Then add from register to score
    mov fruitActive, 0      ; Deactivate fruit
    mov powerUpActive, 1    ; Activate power-up
    mov powerUpTimer, 0     ; Reset power-up timer
    jmp NotTeleportUp

CheckTeleportUp:
    ; Check for teleport pad in level 3
    cmp currentLevel, 3
    jne NotTeleportUp
    cmp al, teleportPadChar
    jne NotTeleportUp

    ; Play teleport sound
    pushad                  ; Save all registers
    INVOKE PlaySoundFile, ADDR teleportSoundFile, teleportSoundFreq, teleportSoundDur
    popad                   ; Restore all registers

    ; Teleport to the other pad
    cmp ebx, teleport1Pos
    jne CheckTeleport2Up

    ; Teleporting from pad 1 to pad 2
    mov ebx, teleport2Pos
    jmp NotTeleportUp

CheckTeleport2Up:
    ; Teleporting from pad 2 to pad 1
    mov ebx, teleport1Pos

NotTeleportUp:
    ; Valid move, update pacman position
    call MovePacman
    mov pacmanPos, ebx
    jmp ContinueGame

ProcessMoveRight:
    ; Calculate new position (current + 1)
    mov ebx, pacmanPos
    inc ebx
    ; Check if valid move
    movzx eax, grid[ebx]
    cmp al, wallChar
    je CheckLevel2Wall
    ; Check for ghost collision
    cmp al, ghostChar
    je GhostCollision

    ; Check for fruit - explicit fruit check
    cmp al, fruitChar
    jne CheckTeleportRight

    ; Collect fruit
    mov eax, fruitPoints    ; Move fruitPoints to register first
    add score, eax          ; Then add from register to score
    mov fruitActive, 0      ; Deactivate fruit
    mov powerUpActive, 1    ; Activate power-up
    mov powerUpTimer, 0     ; Reset power-up timer
    jmp NotTeleportRight

CheckTeleportRight:
    ; Check for teleport pad in level 3
    cmp currentLevel, 3
    jne NotTeleportRight
    cmp al, teleportPadChar
    jne NotTeleportRight

    ; Play teleport sound
    pushad                  ; Save all registers
    INVOKE PlaySoundFile, ADDR teleportSoundFile, teleportSoundFreq, teleportSoundDur
    popad                   ; Restore all registers

    ; Teleport to the other pad
    cmp ebx, teleport1Pos
    jne CheckTeleport2Right

    ; Teleporting from pad 1 to pad 2
    mov ebx, teleport2Pos
    jmp NotTeleportRight

CheckTeleport2Right:
    ; Teleporting from pad 2 to pad 1
    mov ebx, teleport1Pos

NotTeleportRight:
    ; Valid move, update pacman position
    call MovePacman
    mov pacmanPos, ebx
    jmp ContinueGame

ProcessMoveDown:
    ; Calculate new position (current + gridWidth)
    mov ebx, pacmanPos
    add ebx, gridWidth
    ; Check if valid move
    movzx eax, grid[ebx]
    cmp al, wallChar
    je CheckLevel2Wall
    ; Check for ghost collision
    cmp al, ghostChar
    je GhostCollision

    ; Check for fruit - explicit fruit check
    cmp al, fruitChar
    jne CheckTeleportDown

    ; Collect fruit
    mov eax, fruitPoints    ; Move fruitPoints to register first
    add score, eax          ; Then add from register to score
    mov fruitActive, 0      ; Deactivate fruit
    mov powerUpActive, 1    ; Activate power-up
    mov powerUpTimer, 0     ; Reset power-up timer
    jmp NotTeleportDown

CheckTeleportDown:
    ; Check for teleport pad in level 3
    cmp currentLevel, 3
    jne NotTeleportDown
    cmp al, teleportPadChar
    jne NotTeleportDown

    ; Play teleport sound
    pushad                  ; Save all registers
    INVOKE PlaySoundFile, ADDR teleportSoundFile, teleportSoundFreq, teleportSoundDur
    popad                   ; Restore all registers

    ; Teleport to the other pad
    cmp ebx, teleport1Pos
    jne CheckTeleport2Down

    ; Teleporting from pad 1 to pad 2
    mov ebx, teleport2Pos
    jmp NotTeleportDown

CheckTeleport2Down:
    ; Teleporting from pad 2 to pad 1
    mov ebx, teleport1Pos

NotTeleportDown:
    ; Valid move, update pacman position
    call MovePacman
    mov pacmanPos, ebx
    jmp ContinueGame

ProcessMoveLeft:
    ; Calculate new position (current - 1)
    mov ebx, pacmanPos
    dec ebx
    ; Check if valid move
    movzx eax, grid[ebx]
    cmp al, wallChar
    je CheckLevel2Wall
    ; Check for ghost collision
    cmp al, ghostChar
    je GhostCollision

    ; Check for fruit - explicit fruit check
    cmp al, fruitChar
    jne CheckTeleportLeft

    ; Collect fruit
    mov eax, fruitPoints    ; Move fruitPoints to register first
    add score, eax          ; Then add from register to score
    mov fruitActive, 0      ; Deactivate fruit
    mov powerUpActive, 1    ; Activate power-up
    mov powerUpTimer, 0     ; Reset power-up timer
    jmp NotTeleportLeft

CheckTeleportLeft:
    ; Check for teleport pad in level 3
    cmp currentLevel, 3
    jne NotTeleportLeft
    cmp al, teleportPadChar
    jne NotTeleportLeft

    ; Play teleport sound
    pushad                  ; Save all registers
    INVOKE PlaySoundFile, ADDR teleportSoundFile, teleportSoundFreq, teleportSoundDur
    popad                   ; Restore all registers

    ; Teleport to the other pad
    cmp ebx, teleport1Pos
    jne CheckTeleport2Left

    ; Teleporting from pad 1 to pad 2
    mov ebx, teleport2Pos
    jmp NotTeleportLeft

CheckTeleport2Left:
    ; Teleporting from pad 2 to pad 1
    mov ebx, teleport1Pos

NotTeleportLeft:
    ; Valid move, update pacman position
    call MovePacman
    mov pacmanPos, ebx
    jmp ContinueGame

CheckLevel2Wall:
    ; In all levels, hitting a wall costs a life
    dec lives

    ; Check if game over
    cmp lives, 0
    je CheckGameOver

    ; Not game over, reset Pacman position
    ; Clear old position
    mov esi, pacmanPos
    mov al, emptyChar
    mov grid[esi], al

    ; Move Pacman back to start
    mov eax, 15        ; Middle row
    mul gridWidth
    add eax, 32        ; Middle column
    mov pacmanPos, eax
    mov esi, eax
    mov al, pacmanChar
    mov grid[esi], al

    ; Reset last direction when hit by wall
    mov lastDirection, 0

    jmp ContinueGame

SkipMovement:
    jmp ContinueGame

GhostCollision:
    call HandleGhostCollision
    jmp ContinueGame

ContinueGame:
    ; Move ghosts after player moves
    call MoveGhosts

    ; Check if game is still running
    cmp gameRunning, 0
    je CheckGameOver

    ; Redraw grid after valid move
    call DrawGrid

    ; Display instructions again
    mov dl, 0
    mov dh, 34
    call Gotoxy
    mov edx, OFFSET msgQuit
    call WriteString

    ; Back to waiting for input
    jmp GameLoopStart

QuitGame:
    mov gameRunning, 0
    mov gameEndReason, 3  ; 3 = quit by player

CheckGameOver:
    call GameOver

GameLoopEnd:
    ; Wait for a keypress before exiting
    call ReadChar

    ret
GameLoop ENDP

; Moves the pacman to a new position
MovePacman PROC
    ; Update the grid:
    ; 1. Check if moving to a dot
    movzx eax, grid[ebx]
    cmp al, dotChar
    jne NotDot
    add score, 2       ; Increase score by 2 for eating a dot

    ; Play pellet sound
    push ebx           ; Save position
    INVOKE PlaySoundFile, ADDR pelletSoundFile, pelletSoundFreq, pelletSoundDur
    pop ebx            ; Restore position

    ; Decrement remaining dots counter
    dec remainingDots

    ; Check if all dots are collected
    cmp remainingDots, 0
    jne NotDot

    ; All dots collected, end the game
    mov gameRunning, 0
    mov gameEndReason, 2  ; 2 = all pellets collected
NotDot:
    ; Check if moving to a fruit
    cmp al, fruitChar
    jne NotFruit
    add score, 20      ; Increase score by 20 for eating fruit
    mov fruitActive, 0 ; Deactivate fruit
    mov powerUpActive, 1 ; Activate power-up
    mov powerUpTimer, 0  ; Reset power-up timer
NotFruit:
    ; Check if moving to a ghost
    cmp al, ghostChar
    je CheckGhostCollision
    cmp al, vulnerableGhostChar
    je KillGhost

    ; Check if moving to a teleport pad (Level 3 only)
    cmp currentLevel, 3
    jne ContinueMove
    cmp al, teleportPadChar
    jne ContinueMove

    ; Teleport detected, play sound
    push ebx           ; Save registers
    INVOKE PlaySoundFile, ADDR teleportSoundFile, teleportSoundFreq, teleportSoundDur
    pop ebx            ; Restore registers

    jmp ContinueMove

CheckGhostCollision:
    ; If power-up is active, treat as vulnerable ghost
    cmp powerUpActive, 1
    je KillGhost
    ; Otherwise, handle as normal ghost collision
    call HandleGhostCollision
    ret

KillGhost:
    ; Add points for killing ghost
    add score, 20

    ; Find which ghost was killed and reset its position
    cmp ebx, ghost1Pos
    je ResetGhost1
    cmp ebx, ghost2Pos
    je ResetGhost2
    cmp ebx, ghost3Pos
    je ResetGhost3
    cmp ebx, ghost4Pos
    je ResetGhost4

    ; Check if Level 2 and this is Ghost 5
    cmp currentLevel, 2
    jne CheckLevel3Ghosts
    cmp ebx, ghost5Pos
    je ResetGhost5
    jmp ContinueMove

CheckLevel3Ghosts:
    ; Check if Level 3 and this is Ghost 6 or 7
    cmp currentLevel, 3
    jne ContinueMove

    ; Check for Ghost 6
    cmp ebx, ghost6Pos
    je ResetGhost6

    ; Check for Ghost 7
    cmp ebx, ghost7Pos
    je ResetGhost7
    jmp ContinueMove

ResetGhost6:
    mov eax, 8         ; Reset to initial position (top middle)
    mul gridWidth
    add eax, 32
    mov ghost6Pos, eax
    jmp ContinueMove

ResetGhost7:
    mov eax, 23        ; Reset to initial position (bottom middle)
    mul gridWidth
    add eax, 32
    mov ghost7Pos, eax
    jmp ContinueMove

ResetGhost1:
    mov eax, 3         ; Reset to initial position (top left)
    mul gridWidth
    add eax, 3
    mov ghost1Pos, eax
    jmp ContinueMove

ResetGhost2:
    mov eax, 3         ; Reset to initial position (top right)
    mul gridWidth
    add eax, 60
    mov ghost2Pos, eax
    jmp ContinueMove

ResetGhost3:
    mov eax, 28        ; Reset to initial position (bottom left)
    mul gridWidth
    add eax, 3
    mov ghost3Pos, eax
    jmp ContinueMove

ResetGhost4:
    mov eax, 28        ; Reset to initial position (bottom right)
    mul gridWidth
    add eax, 60
    mov ghost4Pos, eax
    jmp ContinueMove

ResetGhost5:
    mov eax, 15        ; Reset to initial position (middle left)
    mul gridWidth
    add eax, 15
    mov ghost5Pos, eax

ContinueMove:
    ; 2. Clear old position
    mov esi, pacmanPos
    mov al, emptyChar
    mov grid[esi], al

    ; 3. Set new position
    mov al, pacmanChar
    mov grid[ebx], al

    ret
MovePacman ENDP

; Move ghosts toward Pacman
MoveGhosts PROC
    ; Before moving ghosts, update their appearance based on power-up state
    mov esi, ghost1Pos
    call UpdateGhostAppearance
    mov esi, ghost2Pos
    call UpdateGhostAppearance
    mov esi, ghost3Pos
    call UpdateGhostAppearance
    mov esi, ghost4Pos
    call UpdateGhostAppearance

    ; Update Ghost 5 appearance if in Level 2
    cmp currentLevel, 2
    jne CheckLevel3GhostAppearance
    mov esi, ghost5Pos
    call UpdateGhostAppearance
    jmp SkipExtraGhostAppearance

CheckLevel3GhostAppearance:
    ; Update Ghosts 6 and 7 appearance if in Level 3
    cmp currentLevel, 3
    jne SkipExtraGhostAppearance
    mov esi, ghost6Pos
    call UpdateGhostAppearance
    mov esi, ghost7Pos
    call UpdateGhostAppearance

SkipExtraGhostAppearance:

    ; Move Ghost 1
    mov ebx, ghost1Pos
    call MoveGhostTowardPacman
    mov ghost1Pos, ebx

    ; Move Ghost 2
    mov ebx, ghost2Pos
    call MoveGhostTowardPacman
    mov ghost2Pos, ebx

    ; Move Ghost 3
    mov ebx, ghost3Pos
    call MoveGhostTowardPacman
    mov ghost3Pos, ebx

    ; Move Ghost 4
    mov ebx, ghost4Pos
    call MoveGhostTowardPacman
    mov ghost4Pos, ebx

    ; Move Ghost 5 if in Level 2
    cmp currentLevel, 2
    jne CheckLevel3Ghosts
    mov ebx, ghost5Pos
    call MoveGhostTowardPacman
    mov ghost5Pos, ebx
    jmp SkipExtraGhostMovement

CheckLevel3Ghosts:
    ; Move Ghosts 6 and 7 if in Level 3
    cmp currentLevel, 3
    jne SkipExtraGhostMovement

    ; Move Ghost 6 (cyan)
    mov ebx, ghost6Pos
    call MoveGhostTowardPacman
    mov ghost6Pos, ebx

    ; Move Ghost 7 (magenta)
    mov ebx, ghost7Pos
    call MoveGhostTowardPacman
    mov ghost7Pos, ebx

    ; For Level 3, move ghosts a second time (2x speed)
    ; Move Ghost 1 again
    mov ebx, ghost1Pos
    call MoveGhostTowardPacman
    mov ghost1Pos, ebx

    ; Move Ghost 2 again
    mov ebx, ghost2Pos
    call MoveGhostTowardPacman
    mov ghost2Pos, ebx

    ; Move Ghost 3 again
    mov ebx, ghost3Pos
    call MoveGhostTowardPacman
    mov ghost3Pos, ebx

    ; Move Ghost 4 again
    mov ebx, ghost4Pos
    call MoveGhostTowardPacman
    mov ghost4Pos, ebx

    ; Move Ghost 6 again (cyan)
    mov ebx, ghost6Pos
    call MoveGhostTowardPacman
    mov ghost6Pos, ebx

    ; Move Ghost 7 again (magenta)
    mov ebx, ghost7Pos
    call MoveGhostTowardPacman
    mov ghost7Pos, ebx

SkipExtraGhostMovement:

    ret
MoveGhosts ENDP

; Updates ghost appearance based on power-up state
; Input: esi = ghost position
UpdateGhostAppearance PROC
    pushad

    ; Check if power-up is active
    cmp powerUpActive, 1
    jne NotVulnerable

    ; Make ghost vulnerable (lowercase 'p')
    mov al, vulnerableGhostChar
    mov grid[esi], al
    jmp DoneUpdateAppearance

NotVulnerable:
    ; Make ghost normal (uppercase 'P')
    mov al, ghostChar
    mov grid[esi], al

DoneUpdateAppearance:
    popad
    ret
UpdateGhostAppearance ENDP

; Moves a single ghost toward Pacman
MoveGhostTowardPacman PROC
    ; Save original position
    mov esi, ebx

    ; Ensure ghost position is valid
    cmp esi, 0
    jl GhostPositionInvalid
    cmp esi, 2047     ; 2048-1 = max index
    jg GhostPositionInvalid

    ; Save what's currently under the ghost
    movzx eax, lastCellContent
    mov grid[esi], al  ; Restore the cell content before moving

    ; Determine ghost row and column
    mov eax, ebx
    xor edx, edx
    div gridWidth
    mov tempRow, eax   ; Save ghost row
    mov tempCol, edx   ; Save ghost column

    ; Determine pacman row and column
    mov eax, pacmanPos
    xor edx, edx
    div gridWidth      ; eax = pacman row, edx = pacman column

    ; Try to move toward Pacman
    mov ecx, 4
    call RandomRange   ; 25% chance of random movement
    cmp eax, 3
    je RandomMove

    ; Compare rows
    cmp eax, tempRow
    jg TryMoveDown
    jl TryMoveUp

    ; Compare columns
    cmp edx, tempCol
    jg TryMoveRight
    jl TryMoveLeft
    jmp NoMove

TryMoveUp:
    mov ebx, esi
    sub ebx, gridWidth
    call CheckGhostMove
    jc TryMoveLeft
    jmp UpdateGhost

TryMoveRight:
    mov ebx, esi
    inc ebx
    call CheckGhostMove
    jc TryMoveUp
    jmp UpdateGhost

TryMoveDown:
    mov ebx, esi
    add ebx, gridWidth
    call CheckGhostMove
    jc TryMoveRight
    jmp UpdateGhost

TryMoveLeft:
    mov ebx, esi
    dec ebx
    call CheckGhostMove
    jc TryMoveDown
    jmp UpdateGhost

RandomMove:
    mov ecx, 4
    call RandomRange
    cmp eax, 0
    je TryMoveUp
    cmp eax, 1
    je TryMoveRight
    cmp eax, 2
    je TryMoveDown
    jmp TryMoveLeft

NoMove:
GhostPositionInvalid:
    mov ebx, esi      ; Stay in current position
    jmp GhostMoveDone

UpdateGhost:
    ; Check if proposed position is valid
    cmp ebx, 0
    jl NoMove
    cmp ebx, 2047     ; 2048-1 = max index
    jg NoMove

    ; Check for collision with Pacman
    cmp ebx, pacmanPos
    jne NoCollision

    ; Handle collision - don't move ghost to Pacman's position
    ; instead, call collision handler and stay in place
    push ebx          ; Save ghost's intended position
    call HandleGhostCollision
    pop ebx
    mov ebx, esi      ; Stay in current position
    jmp GhostMoveDone

NoCollision:
    ; Check if position is valid (not a wall or another ghost)
    movzx eax, grid[ebx]
    cmp al, wallChar
    je StayInPlace
    cmp al, ghostChar
    je StayInPlace
    cmp al, vulnerableGhostChar
    je StayInPlace

    ; Save what's under the ghost's new position
    mov lastCellContent, al

    ; Place ghost in new position
    cmp powerUpActive, 1
    jne NormalGhost
    mov al, vulnerableGhostChar
    jmp PlaceGhost
NormalGhost:
    mov al, ghostChar
PlaceGhost:
    mov grid[ebx], al
    jmp GhostMoveDone

StayInPlace:
    ; Can't move to new position, stay in current position
    mov ebx, esi

GhostMoveDone:
    ret
MoveGhostTowardPacman ENDP

; Checks if a ghost can move to the specified position
; Input: ebx = target position
; Output: Carry flag set if move is invalid
CheckGhostMove PROC
    ; Check grid boundaries
    cmp ebx, 0
    jl InvalidMove
    cmp ebx, 2047     ; 2048 - 1
    jg InvalidMove

    ; Check for wall or other ghost
    movzx eax, grid[ebx]
    cmp al, wallChar
    je InvalidMove
    cmp al, ghostChar
    je InvalidMove

    clc               ; Clear carry flag (move is valid)
    ret

InvalidMove:
    stc               ; Set carry flag (move is invalid)
    ret
CheckGhostMove ENDP

; Draws the grid on the screen
DrawGrid PROC
    pushad

    ; Set color to black text on white background
    mov eax, black + (white * 16)    ; black text (0) on white background (15 * 16)
    call SetTextColor

    ; Clear the screen
    call Clrscr

    ; Display player name
    mov dl, 0
    mov dh, 0
    call Gotoxy
    mov edx, OFFSET nameMsg
    call WriteString
    mov edx, OFFSET playerName
    call WriteString

    ; Display score and lives
    mov dl, 30
    mov dh, 0
    call Gotoxy
    mov edx, OFFSET scoreMsg
    call WriteString
    mov eax, score
    call WriteDec

    ; Display lives
    mov dl, 50
    mov dh, 0
    call Gotoxy
    mov edx, OFFSET livesMsg
    call WriteString
    mov eax, lives
    call WriteDec

    ; Move cursor to start of grid (row 1)
    mov dl, 0
    mov dh, 1
    call Gotoxy

    ; Draw the grid
    mov ecx, gridHeight
    xor edi, edi
    mov dh, 1         ; Start at row 1 to leave room for score

DrawRowLoopStart:
    push ecx
    mov dl, 0
    call Gotoxy

    mov ecx, gridWidth
DrawColLoopStart:
    movzx eax, grid[edi]

    ; Special handling for walls based on level
    cmp al, wallChar
    jne CheckFruit

    ; Determine which level we're in and use appropriate wall color
    movzx ebx, currentLevel    ; Fix size mismatch by using movzx
    cmp ebx, 1
    je UseLevel1WallColor
    cmp ebx, 2
    je UseLevel2WallColor
    cmp ebx, 3
    je UseLevel3WallColor
    jmp StandardDraw           ; Default case

UseLevel1WallColor:
    ; For Level 1, walls have blue background
    push eax
    mov ax, wallColorLevel1    ; Use ax for 16-bit color value
    movzx eax, ax             ; Zero-extend to 32 bits for SetTextColor
    call SetTextColor
    pop eax
    call WriteChar

    ; Reset color after drawing wall
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

UseLevel2WallColor:
    ; For Level 2, walls have red background
    push eax
    mov ax, wallColorLevel2    ; Use ax for 16-bit color value
    movzx eax, ax             ; Zero-extend to 32 bits for SetTextColor
    call SetTextColor
    pop eax
    call WriteChar

    ; Reset color after drawing wall
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

UseLevel3WallColor:
    ; For Level 3, walls have green background
    push eax
    mov ax, wallColorLevel3    ; Use ax for 16-bit color value
    movzx eax, ax             ; Zero-extend to 32 bits for SetTextColor
    call SetTextColor
    pop eax
    call WriteChar

    ; Reset color after drawing wall
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

CheckFruit:
    ; Check if it's a fruit - always use bright yellow for fruit to ensure visibility
    cmp al, fruitChar
    jne NotFruit

    ; For fruit, use bright yellow on blue background
    push eax
    mov eax, (yellow + 8) + (blue * 16)   ; Bright yellow on blue background
    call SetTextColor
    pop eax
    call WriteChar

    ; Reset color after drawing fruit
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

NotFruit:
    ; Check if it's a teleport pad (Level 3 only)
    cmp currentLevel, 3
    jne CheckIfGhost
    cmp al, teleportPadChar
    jne CheckIfGhost

    ; For teleport pads, use bright cyan on black background
    push eax
    mov eax, (cyan + 8) + (black * 16)   ; Bright cyan on black background
    call SetTextColor
    pop eax
    call WriteChar

    ; Reset color after drawing teleport pad
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

CheckIfGhost:
    ; Check if it's a ghost
    cmp al, ghostChar
    jne NotGhost

    ; Determine which ghost it is and use appropriate color
    cmp edi, ghost1Pos
    jne NotGhost1
    ; Ghost 1 - Red
    push eax
    mov ax, ghost1Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

NotGhost1:
    cmp edi, ghost2Pos
    jne NotGhost2
    ; Ghost 2 - Brown
    push eax
    mov ax, ghost2Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

NotGhost2:
    cmp edi, ghost3Pos
    jne NotGhost3
    ; Ghost 3 - Green
    push eax
    mov ax, ghost3Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

NotGhost3:
    cmp edi, ghost4Pos
    jne NotGhost4
    ; Ghost 4 - Orange
    push eax
    mov ax, ghost4Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

NotGhost4:
    ; Check if Level 2 and this is Ghost 5
    cmp currentLevel, 2
    jne CheckLevel3Ghosts
    cmp edi, ghost5Pos
    jne StandardGhost
    ; Ghost 5 - Pink (Level 2 only)
    push eax
    mov ax, ghost5Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

CheckLevel3Ghosts:
    ; Check if Level 3 and this is Ghost 6 or 7
    cmp currentLevel, 3
    jne StandardGhost

    ; Check for Ghost 6 (cyan)
    cmp edi, ghost6Pos
    jne CheckGhost7
    push eax
    mov ax, ghost6Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

CheckGhost7:
    ; Check for Ghost 7 (magenta)
    cmp edi, ghost7Pos
    jne StandardGhost
    push eax
    mov ax, ghost7Color
    movzx eax, ax
    call SetTextColor
    pop eax
    call WriteChar
    jmp ResetGhostColor

StandardGhost:
    ; Default ghost color (should not reach here normally)
    call WriteChar
    jmp ContinueDrawing

ResetGhostColor:
    ; Reset color after drawing ghost
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

NotGhost:
    ; Check if it's a vulnerable ghost
    cmp al, vulnerableGhostChar
    jne StandardDraw

    ; For vulnerable ghost, use blue text
    push eax
    mov eax, blue + (white * 16)
    call SetTextColor
    pop eax
    call WriteChar

    ; Reset color after drawing vulnerable ghost
    push eax
    mov eax, black + (white * 16)
    call SetTextColor
    pop eax
    jmp ContinueDrawing

StandardDraw:
    call WriteChar

ContinueDrawing:
    inc edi
    dec ecx                    ; Manually decrement counter
    jnz DrawColLoopStart       ; Use jnz instead of loop

    inc dh
    pop ecx
    dec ecx                    ; Manually decrement counter
    jnz DrawRowLoopStart       ; Use jnz instead of loop

    ; Display controls message
    mov dl, 0
    mov dh, 34
    call Gotoxy
    mov edx, OFFSET msgQuit
    call WriteString

    popad
    ret
DrawGrid ENDP

; Clean up resources before exiting
CleanupGame PROC
    ; Show the cursor again before exiting
    mov cursorInfo.dwSize, 100
    mov cursorInfo.bVisible, 1
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo
    ret
CleanupGame ENDP

; Updates Level 2 specific features
UpdateLevel2Features PROC
    ; Only process if we're in Level 2
    cmp currentLevel, 2
    je L2_ProcessFeatures
    ret                     ; Exit immediately if not in Level 2

L2_ProcessFeatures:
    ; Move walls immediately (no timer)
    call SlideWalls

    ; Update fruit timer - simplified
    inc fruitTimer

    ; Force spawn fruit every 5 ticks (even faster for testing)
    mov eax, fruitTimer
    cmp eax, 5
    jl SkipFruitHandling

    ; Reset timer
    mov fruitTimer, 0

    ; Always force a fruit at fixed position (row 10, column 30)
    mov eax, 10
    mul gridWidth
    add eax, 30
    mov esi, eax

    ; Place the fruit regardless of what was there before
    mov al, fruitChar
    mov grid[esi], al
    mov fruitActive, 1
    mov fruitPos, esi

SkipFruitHandling:
    ; Update power-up timer if active
    cmp powerUpActive, 1
    je CheckPowerUpTimer
    ret                     ; Exit if no power-up is active

CheckPowerUpTimer:
    inc powerUpTimer
    mov eax, powerUpTimer
    cmp eax, powerUpDuration
    jl PowerUpStillActive   ; Short jump if still active

    ; Power-up expired
    mov powerUpActive, 0
    mov powerUpTimer, 0

PowerUpStillActive:
    ret
UpdateLevel2Features ENDP

; Updates Level 3 specific features
UpdateLevel3Features PROC
    ; Only process if we're in Level 3
    cmp currentLevel, 3
    je L3_ProcessFeatures
    ret                     ; Exit immediately if not in Level 3

L3_ProcessFeatures:
    ; Move walls horizontally like in level 2
    call SlideWalls

    ; Update fruit timer - simplified
    inc fruitTimer

    ; Force spawn fruit every 5 ticks (even faster for testing)
    mov eax, fruitTimer
    cmp eax, 5
    jl SkipFruitHandling

    ; Reset timer
    mov fruitTimer, 0

    ; Always force a fruit at fixed position (row 15, column 45)
    mov eax, 15
    mul gridWidth
    add eax, 45
    mov esi, eax

    ; Place the fruit regardless of what was there before
    mov al, fruitChar
    mov grid[esi], al
    mov fruitActive, 1
    mov fruitPos, esi

SkipFruitHandling:
    ; Update power-up timer if active
    cmp powerUpActive, 1
    je CheckPowerUpTimer
    ret                     ; Exit if no power-up is active

CheckPowerUpTimer:
    inc powerUpTimer
    mov eax, powerUpTimer
    cmp eax, powerUpDuration
    jl PowerUpStillActive   ; Short jump if still active

    ; Power-up expired
    mov powerUpActive, 0
    mov powerUpTimer, 0

PowerUpStillActive:
    ret
UpdateLevel3Features ENDP

; Removed all vertical column sliding procedures as they're no longer needed

; Slides the walls for Level 2
SlideWalls PROC
    ; Store registers
    pushad

    ; Move walls one step right in each wall row
    ; Each row will reset independently when it hits the border

    ; Row 1 (row 6)
    mov eax, 6
    call MoveWallsRight

    ; Row 2 (row 12)
    mov eax, 12
    call MoveWallsRight

    ; Row 3 (row 18)
    mov eax, 18
    call MoveWallsRight

    ; Row 4 (row 24)
    mov eax, 24
    call MoveWallsRight

    ; Restore registers
    popad
    ret
SlideWalls ENDP

; Helper procedure to move walls right by one position
; Input: eax = row number
MoveWallsRight PROC
    pushad              ; Save all registers

    ; Calculate start position (rightmost possible position)
    mov ebx, eax        ; Save row number
    mul gridWidth
    add eax, 61         ; Start from second-to-last column
    mov esi, eax

    ; Check if we need to reset this row
    movzx eax, grid[esi]
    cmp al, wallChar
    je ResetThisRow

    ; Process from right to left
    mov ecx, 60         ; Number of columns to process (excluding borders)
MoveWallsLoopStart:
    ; Check if current position has a wall
    movzx eax, grid[esi]
    cmp al, wallChar
    jne NotWall

    ; It's a wall, check if we can move it right
    movzx edx, grid[esi+1]
    cmp dl, wallChar    ; Don't move if there's already a wall to the right
    je NotWall
    cmp dl, ghostChar   ; Don't move if there's a ghost to the right
    je NotWall
    cmp dl, pacmanChar  ; Don't move if Pacman is to the right
    je NotWall

    ; Safe to move wall right
    mov grid[esi+1], al  ; Move wall to the right

    ; Replace current position with dot or empty
    cmp esi, pacmanPos   ; Check if this was Pacman's position
    je PutEmptyChar

    ; Put a dot by default
    mov al, dotChar
    mov grid[esi], al
    jmp NotWall

PutEmptyChar:
    mov al, emptyChar
    mov grid[esi], al

NotWall:
    dec esi              ; Move to previous column
    dec ecx              ; Manually decrement counter
    jnz MoveWallsLoopStart  ; Use jnz instead of loop
    jmp MoveWallsDone

ResetThisRow:
    ; Reset just this row
    mov eax, ebx        ; Restore row number
    call ResetRowToLeft

    ; Add a very small delay just for visual clarity
    mov eax, 10        ; 10ms delay
    call Delay

MoveWallsDone:
    popad                ; Restore all registers
    ret
MoveWallsRight ENDP

; Helper procedure to reset a row to leftmost position
; Input: eax = row number
ResetRowToLeft PROC
    pushad              ; Save all registers

    ; Calculate start position
    mov ebx, eax        ; Save row number
    mul gridWidth
    mov esi, eax
    add esi, 1          ; Skip left border

    ; First clear all wall characters, preserving everything else
    mov ecx, 62         ; Number of columns (excluding borders)
ClearWallsLoopStart:
    movzx eax, grid[esi]
    cmp al, wallChar
    jne SkipClear
    mov al, dotChar
    mov grid[esi], al
SkipClear:
    inc esi
    dec ecx              ; Manually decrement counter
    jnz ClearWallsLoopStart  ; Use jnz instead of loop

    ; Now place walls in their initial positions based on row
    cmp ebx, 6          ; First row
    je PlaceRow1Walls
    cmp ebx, 12         ; Second row
    je PlaceRow2Walls
    cmp ebx, 18         ; Third row
    je PlaceRow3Walls
    cmp ebx, 24         ; Fourth row
    je PlaceRow4Walls
    jmp ResetDone

PlaceRow1Walls:
    ; 2 walls of 8 units each
    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 16         ; First wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow1Wall1Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow1Wall1Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 40         ; Second wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow1Wall2Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow1Wall2Start  ; Use jnz instead of loop
    jmp near ptr ResetDone

PlaceRow2Walls:
    ; 5 walls of 8 units each
    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 4          ; First wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow2Wall1Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow2Wall1Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 16         ; Second wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow2Wall2Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow2Wall2Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 28         ; Third wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow2Wall3Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow2Wall3Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 40         ; Fourth wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow2Wall4Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow2Wall4Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 52         ; Fifth wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow2Wall5Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow2Wall5Start  ; Use jnz instead of loop
    jmp near ptr ResetDone

PlaceRow3Walls:
    ; 3 walls of 8 units each
    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 12         ; First wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow3Wall1Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow3Wall1Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 28         ; Second wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow3Wall2Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow3Wall2Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 44         ; Third wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow3Wall3Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow3Wall3Start  ; Use jnz instead of loop
    jmp near ptr ResetDone

PlaceRow4Walls:
    ; 5 walls of 8 units each (same as row 2)
    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 4          ; First wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow4Wall1Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow4Wall1Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 16         ; Second wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow4Wall2Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow4Wall2Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 28         ; Third wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow4Wall3Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow4Wall3Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 40         ; Fourth wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow4Wall4Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow4Wall4Start  ; Use jnz instead of loop

    mov eax, ebx        ; Row number
    mul gridWidth
    add eax, 52         ; Fifth wall position
    mov esi, eax
    mov ecx, 8
    mov al, wallChar    ; Load wall character into al
PlaceRow4Wall5Start:
    mov grid[esi], al   ; Place wall character
    inc esi
    dec ecx              ; Manually decrement counter
    jnz PlaceRow4Wall5Start  ; Use jnz instead of loop

ResetDone:
    popad               ; Restore all registers
    ret
ResetRowToLeft ENDP

; Handle ghost collision with Pacman
HandleGhostCollision PROC
    pushad              ; Save all registers

    ; Check if power-up is active
    mov al, powerUpActive
    cmp al, 1
    je GhostPowerUpActive

    ; No power-up, decrease life - play death sound
    dec lives

    ; Play death sound
    INVOKE PlaySoundFile, ADDR deathSoundFile, deathSoundFreq, deathSoundDur

    ; Check if game over
    cmp lives, 0
    je HandleGameOver

    ; Not game over, reset Pacman position
    ; Clear old position
    mov esi, pacmanPos
    mov al, emptyChar
    mov grid[esi], al

    ; Move Pacman back to start
    mov eax, 15        ; Middle row
    mul gridWidth
    add eax, 32        ; Middle column
    mov pacmanPos, eax
    mov esi, eax
    mov al, pacmanChar
    mov grid[esi], al

    ; Reset last direction when hit by ghost
    mov lastDirection, 0

    jmp HandleGhostDone

GhostPowerUpActive:
    ; Power-up is active, add points instead of losing a life
    add score, 50      ; Add 50 points for eating a ghost during power-up
    jmp HandleGhostDone

HandleGameOver:
    ; Set game running to false
    mov gameRunning, 0
    mov gameEndReason, 1  ; 1 = lives lost

HandleGhostDone:
    popad               ; Restore all registers
    ret
HandleGhostCollision ENDP

; Toggle pause state and show/hide pause screen
TogglePause PROC
    ; Toggle pause state
    xor al, al
    mov al, isPaused
    xor al, 1
    mov isPaused, al

    ; If now paused, show pause screen
    cmp al, 1
    je ShowPauseScreen

    ; If now unpaused, redraw game
    call DrawGrid
    ret

ShowPauseScreen:
    ; Clear screen
    call Clrscr

    ; Display PAUSED art
    mov dl, 0
    mov dh, 0
    call Gotoxy
    mov edx, OFFSET pauseArt
    call WriteString
    call Crlf
    call Crlf

    ; Display Instructions art
    mov edx, OFFSET instructionsArt
    call WriteString
    call Crlf
    call Crlf

    ; Display instructions
    mov edx, OFFSET instruction1
    call WriteString
    call Crlf
    mov edx, OFFSET instruction2
    call WriteString
    call Crlf
    mov edx, OFFSET instruction3
    call WriteString
    call Crlf
    mov edx, OFFSET instruction4
    call WriteString
    call Crlf
    mov edx, OFFSET instruction5
    call WriteString
    call Crlf
    mov edx, OFFSET instruction6
    call WriteString
    call Crlf
    mov edx, OFFSET instruction7
    call WriteString
    call Crlf
    call Crlf
    mov edx, OFFSET instruction8
    call WriteString
    call Crlf
    mov edx, OFFSET instruction9
    call WriteString
    call Crlf
    mov edx, OFFSET instruction10
    call WriteString

    ret
TogglePause ENDP

; Handle game over state
GameOver PROC
    ; Set game running to false
    mov gameRunning, 0

    ; Show the game over screen with ASCII art
    call ShowGameOverScreen

    ret
GameOver ENDP

; Simplified fruit spawning - just used for initialization
SpawnFruit PROC
    pushad            ; Save all registers

    ; Calculate fixed position (row 10, column 30)
    mov eax, 10
    mul gridWidth
    add eax, 30
    mov fruitPos, eax
    mov esi, eax

    ; Force fruit character
    mov al, fruitChar
    mov grid[esi], al
    mov fruitActive, 1

    popad             ; Restore all registers
    ret
SpawnFruit ENDP

; Count the number of dots remaining in the grid
CountRemainingDots PROC
    pushad            ; Save all registers

    ; Reset counter
    mov remainingDots, 0

    ; Loop through the entire grid
    mov ecx, 2048     ; 32 * 64 = 2048 cells
    mov esi, 0

CountDotsLoop:
    ; Check if current cell is a dot
    movzx eax, grid[esi]
    cmp al, dotChar
    jne NotDot

    ; Increment dot counter
    inc remainingDots

NotDot:
    inc esi
    loop CountDotsLoop

    popad             ; Restore all registers
    ret
CountRemainingDots ENDP

; Show game over screen with ASCII art, username, score, and reason
ShowGameOverScreen PROC
    pushad            ; Save all registers

    ; Play game over sound
    INVOKE PlaySoundFile, ADDR gameOverSoundFile, gameOverSoundFreq, gameOverSoundDur

    ; Clear screen
    call Clrscr

    ; Display GAME OVER ASCII art
    mov dl, 0
    mov dh, 0
    call Gotoxy
    mov edx, OFFSET gameOverArt
    call WriteString

    ; Display player name
    mov dl, 10
    mov dh, 24
    call Gotoxy
    mov edx, OFFSET nameMsg
    call WriteString
    mov edx, OFFSET playerName
    call WriteString

    ; Display score
    mov dl, 10
    mov dh, 25
    call Gotoxy
    mov edx, OFFSET scoreMsg
    call WriteString
    mov eax, score
    call WriteDec

    ; Display reason for game ending
    mov dl, 10
    mov dh, 26
    call Gotoxy
    mov edx, OFFSET msgReason
    call WriteString

    ; Check game end reason
    movzx eax, gameEndReason
    cmp eax, 1
    je ShowLivesLostReason
    cmp eax, 2
    je ShowPelletsCollectedReason
    cmp eax, 3
    je ShowQuitReason
    jmp WriteHighscoreSection

ShowLivesLostReason:
    mov edx, OFFSET msgLivesLost
    call WriteString
    jmp WriteHighscoreSection

ShowPelletsCollectedReason:
    mov edx, OFFSET msgAllPelletsCollected
    call WriteString
    jmp WriteHighscoreSection

ShowQuitReason:
    mov edx, OFFSET msgQuitGame
    call WriteString

WriteHighscoreSection:
    ; Add message about saving highscore
    mov dl, 10
    mov dh, 28
    call Gotoxy

    ; Write highscore to file
    call WriteHighscore

GameOverScreenDone:
    popad             ; Restore all registers
    ret
ShowGameOverScreen ENDP

; Write highscore to file in format name,level,score
WriteHighscore PROC
    pushad            ; Save all registers

    ; Clear score buffer
    mov edi, OFFSET scoreBuffer
    mov ecx, 256
    mov al, 0
    rep stosb

    ; Format entry: name,level,score
    ; First copy the name
    mov esi, OFFSET playerName
    mov edi, OFFSET scoreBuffer
    mov ecx, 31                ; Max name length - 1 for null terminator
CopyNameLoop:
    mov al, [esi]
    cmp al, 0                  ; Check for null terminator
    je DoneWithName
    mov BYTE PTR [edi], al
    inc esi
    inc edi
    loop CopyNameLoop
DoneWithName:

    ; Add comma
    mov BYTE PTR [edi], ','
    inc edi

    ; Add level (single digit 1-3)
    mov al, currentLevel
    add al, '0'                ; Convert to ASCII
    mov BYTE PTR [edi], al
    inc edi

    ; Add comma
    mov BYTE PTR [edi], ','
    inc edi

    ; Add score (convert to string)
    mov eax, score
    call MyParseDecimal32      ; Convert EAX to decimal string at EDI

    ; Find end of string to add newline
    mov edi, OFFSET scoreBuffer
FindEndLoop:
    cmp BYTE PTR [edi], 0
    je FoundEnd
    inc edi
    jmp FindEndLoop
FoundEnd:

    ; Add newline at end
    mov BYTE PTR [edi], 13     ; Carriage return
    inc edi
    mov BYTE PTR [edi], 10     ; Line feed
    inc edi
    mov BYTE PTR [edi], 0      ; Null terminator

    ; Try to open the file (append mode)
    INVOKE CreateFile,
        ADDR highscoresFile,   ; File name
        GENERIC_WRITE,         ; Open for writing
        0,                     ; No sharing
        NULL,                  ; Default security
        OPEN_ALWAYS,           ; Open if exists, create if doesn't
        FILE_ATTRIBUTE_NORMAL, ; Normal file attribute
        0                      ; No template

    mov fileHandle, eax        ; Save file handle

    ; Check if file opened successfully
    cmp eax, INVALID_HANDLE_VALUE
    je FileError

    ; Seek to end of file for append
    INVOKE SetFilePointer,
        fileHandle,            ; File handle
        0,                     ; Distance low (0)
        0,                     ; Distance high (0)
        FILE_END               ; Move from end

    ; Calculate string length
    mov edi, OFFSET scoreBuffer
    mov ecx, 0
StrLenLoop:
    cmp BYTE PTR [edi+ecx], 0
    je DoneCountingLength
    inc ecx
    jmp StrLenLoop
DoneCountingLength:

    ; Write the score entry to the file
    INVOKE WriteFile,
        fileHandle,            ; File handle
        ADDR scoreBuffer,      ; Buffer to write from
        ecx,                   ; Number of bytes to write
        ADDR bytesWritten,     ; Number of bytes written
        0                      ; Overlapped structure

    ; Close the file
    INVOKE CloseHandle, fileHandle

FileError:
    popad                      ; Restore all registers
    ret
WriteHighscore ENDP

; Helper procedure: MyParseDecimal32
; Converts a 32-bit integer in EAX to decimal ASCII
; EDI points to the destination buffer
MyParseDecimal32 PROC
    pushad                   ; Save all registers

    mov ecx, 0              ; Digit counter
    mov ebx, 10             ; Divisor

    ; Special case for 0
    test eax, eax
    jnz ConvertLoop
    mov BYTE PTR [edi], '0'
    inc edi
    jmp ParseDone

ConvertLoop:
    ; Exit if number is 0
    test eax, eax
    jz BuildString

    ; Get next digit
    xor edx, edx            ; Clear EDX for division
    div ebx                 ; Divide EAX by 10, remainder in EDX

    ; Convert to ASCII and push onto stack
    add dl, '0'
    push edx
    inc ecx
    jmp ConvertLoop

BuildString:
    ; No more digits or no digits (zero case)
    test ecx, ecx
    jz ParseDone

    ; Pop digits in reverse order
PopLoop:
    pop eax
    mov [edi], al
    inc edi
    loop PopLoop

ParseDone:
    mov BYTE PTR [edi], 0    ; Null-terminate the string
    popad                    ; Restore all registers
    ret
MyParseDecimal32 ENDP



; String for MP3 file type
szTypeMP3 BYTE "type mpegvideo alias pacmanmp3", 0

END main
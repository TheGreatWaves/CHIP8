extends Node2D

# Memory.
var memory: Array[int] = []

# Registers.
var I: int = 0 # Address.
var opcode: int = 0 # Opcode.
var PC: int  = 0x200 # Program counter
var V: Array[int] = []

# Timers.
var delay_timer: int = 0
var sound_timer: int = 0

# Stack & stack pointer.
var stack: Array[int] = [] 
var stack_pointer: int = 0

# Screen.
var screen: Array[bool] = []

# Key state.
var keys: Array[bool] = []

# Set up keys.
func init_keys():
	keys.resize(16)
	keys.fill(false)

# Set up screen.
func init_screen():
	screen.resize(64 * 32)
	screen.fill(false)

# Set up memory.
func init_memory():
	memory.resize(4096)
	memory.fill(0)
	
func init_registers():
	I = 0
	opcode = 0
	delay_timer = 0
	sound_timer = 0
	PC = 0x200
	V.resize(16)
	V.fill(0)

func init_stack():
	stack = []
	stack_pointer = 0
	
func reset_all():
	init_memory()
	init_registers()
	init_stack()
	init_screen()
	
func fetch():
	opcode = (memory[PC] << 8) | memory[PC + 1]
	
func cycle():
	fetch()
	# Decode and execute...
	
# Called when the node enters the scene tree for the first time.
func _ready():
	reset_all()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# At the moment it's being called every frame, however this can be changed 
	# to be listening to a signal which gets invoked by a timer so we can have
	# a fixed time step cycle.
	cycle()

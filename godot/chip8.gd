extends Node2D

# Memory.
var memory: Array[int] = []

# Registers.
var I: int = 0 # Address.
var opcode: int = 0 # Opcode.
var PC: int  = 0x200 # Program counter
var V: Array[int] = []

# Stack & stack pointer.
var stack: Array[int] = [] 
var stack_pointer: int = 0

# Set up memory.
func init_memory():
	memory.resize(4096)
	memory.fill(0)
	
func init_registers():
	I = 0
	opcode = 0
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

# Called when the node enters the scene tree for the first time.
func _ready():
	reset_all()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

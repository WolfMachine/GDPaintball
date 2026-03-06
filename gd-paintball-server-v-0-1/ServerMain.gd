extends Node
class_name ServerMain

# ---------------------------------------------------------
# MODULE PRELOADS
# ---------------------------------------------------------

const SessionManager      = preload("res://modules/SessionManager.gd")
const LoginOrchestrator   = preload("res://modules/LoginOrchestrator.gd")
const HeartbeatManager    = preload("res://modules/HeartbeatManager.gd")
const MatchOrchestrator   = preload("res://modules/MatchOrchestrator.gd")

const QueueManager        = preload("res://modules/QueueManager.gd")
const TeamAssigner        = preload("res://modules/TeamAssigner.gd")
const MatchScheduler      = preload("res://modules/MatchScheduler.gd")
const MatchLifecycle      = preload("res://modules/MatchLifecycle.gd")
const AdminModule         = preload("res://modules/AdminModule.gd")
const RandomNameGenerator = preload("res://modules/RandomNameGenerator.gd")
const PlayerRegistry      = preload("res://modules/PlayerRegistry.gd")
const Login               = preload("res://modules/Login.gd")
const TokenGenerator      = preload("res://modules/TokenGenerator.gd")
const Heartbeat           = preload("res://modules/Heartbeat.gd")

# ---------------------------------------------------------
# SERVER NODES
# ---------------------------------------------------------

var gameplay: Node
var tcp_server: Node
var udp_server: Node

# ---------------------------------------------------------
# CORE MODULES
# ---------------------------------------------------------

var registry
var queue_manager
var team_assigner
var match_scheduler
var match_lifecycle
var admin_module
var name_gen
var login_module
var token_gen
var heartbeat_node

# ---------------------------------------------------------
# ORCHESTRATORS
# ---------------------------------------------------------

var session_manager
var login_orchestrator
var heartbeat_manager
var match_orchestrator

# ---------------------------------------------------------
# READY
# ---------------------------------------------------------

func _ready():
	_initialize_nodes()
	_initialize_modules()
	_wire_modules()
	set_process(true)

# ---------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------

func _initialize_nodes():
	var root := get_tree().root
	var server_root := root.get_node_or_null("ServerRoot")
	if server_root == null:
		push_error("ServerRoot missing")
		return

	gameplay = server_root.get_node_or_null("GameplayController")
	tcp_server = server_root.get_node_or_null("GameTCPServer")
	udp_server = server_root.get_node_or_null("ENetServer")

	if gameplay == null or tcp_server == null or udp_server == null:
		push_error("Missing required server nodes")
		return

func _initialize_modules():
	# Core data modules
	registry = PlayerRegistry.new()
	queue_manager = QueueManager.new()
	team_assigner = TeamAssigner.new()
	match_scheduler = MatchScheduler.new()
	match_lifecycle = MatchLifecycle.new()
	admin_module = AdminModule.new()
	name_gen = RandomNameGenerator.new()
	login_module = Login.new()
	token_gen = TokenGenerator.new()
	heartbeat_node = Heartbeat.new()

	add_child(registry)
	add_child(name_gen)
	add_child(login_module)
	add_child(heartbeat_node)

	login_module.load_users()

	# Orchestrators
	session_manager = SessionManager.new()
	login_orchestrator = LoginOrchestrator.new()
	heartbeat_manager = HeartbeatManager.new()
	match_orchestrator = MatchOrchestrator.new()

	add_child(session_manager)
	add_child(login_orchestrator)
	add_child(heartbeat_manager)
	add_child(match_orchestrator)

# ---------------------------------------------------------
# WIRING
# ---------------------------------------------------------

func _wire_modules():
	# Admin module setup
	admin_module.tcp_server = tcp_server
	admin_module.udp_server = udp_server
	admin_module.gameplay = gameplay
	admin_module.tcp_connections = session_manager.tcp_connections
	admin_module.load_server_config()

	# Session manager
	session_manager.initialize(
		tcp_server,
		udp_server,
		registry,
		token_gen,
		heartbeat_manager,
		admin_module,
		queue_manager,
		login_orchestrator,
		match_orchestrator
	)

	# Login orchestrator
	login_orchestrator.initialize(
		login_module,
		registry,
		session_manager,
		queue_manager,
		admin_module,
		token_gen,
		heartbeat_manager
	)

	# Heartbeat manager
	heartbeat_manager.initialize(
		heartbeat_node,
		session_manager,
		match_lifecycle,
		admin_module
	)

	# Match orchestrator
	match_orchestrator.initialize(
		match_lifecycle,
		match_scheduler,
		team_assigner,
		queue_manager,
		registry,
		admin_module,
		session_manager,
		udp_server,
		gameplay
	)

# ---------------------------------------------------------
# EXPOSED FOR GAMEPLAY
# ---------------------------------------------------------

func get_player_registry():
	return registry

# ---------------------------------------------------------
# PROCESS LOOP
# ---------------------------------------------------------

func _process(delta):
	match_orchestrator.process(delta)

	var shutdown_action = admin_module.process_shutdown_timer()
	if shutdown_action != null:
		if shutdown_action.action == "restart":
			_restart_server()
		else:
			_shutdown_server()

# ---------------------------------------------------------
# SHUTDOWN / RESTART
# ---------------------------------------------------------

func _shutdown_server():
	tcp_server.begin_shutdown()
	if udp_server and udp_server.has_method("begin_shutdown"):
		udp_server.begin_shutdown()
	get_tree().quit(0)

func _restart_server():
	tcp_server.begin_shutdown()
	if udp_server and udp_server.has_method("begin_shutdown"):
		udp_server.begin_shutdown()
	get_tree().quit(42)

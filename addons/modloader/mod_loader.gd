extends Node

const Mod = preload("res://addons/modloader/mod.gd")
const ModBase = preload("res://addons/modloader/mod_base.gd")
const Hook = preload("res://addons/modloader/hook.gd")

signal game_ready

const MODS_DIR = "user://mods/"
const FileWatcher = preload("res://addons/modloader/file_watcher.gd")

var mods = {}
var order = []
var version: String

var dyn_stats: Dictionary = {}
var dyn_mods: Dictionary = {}

var stats_hooked = false

var hooks: Dictionary = {}
var file_watcher
var _game_started_triggered = false

const ModManagerScene = preload("res://addons/modloader/mod_manager.tscn")

func _ready():
    version = ProjectSettings.get_setting("application/config/version", "0.0.0")
    set_process(true)

func _process(_delta):
    if _game_started_triggered:
        return

    var game_node = get_tree().get_root().find_child("Game", true, false)
    if is_instance_valid(game_node):
        _game_started_triggered = true
        _on_game_started()
        set_process(false)

func _on_settings_ready():
    if not DirAccess.dir_exists_absolute(MODS_DIR):
        DirAccess.make_dir_recursive_absolute(MODS_DIR)
    
    file_watcher = FileWatcher.new()
    add_child(file_watcher)
    file_watcher.mods_changed.connect(scan_and_load_mods)
    file_watcher.start_watching(MODS_DIR)

    _initialize_button_injection()
    scan_and_load_mods()

func _initialize_button_injection():
    await get_tree().process_frame
    var main_menu = get_tree().get_root().find_child("MainMenu", true, false)
    if main_menu:
        _inject_mods_button(main_menu)

func _inject_mods_button(main_menu_node):
    var signpost = main_menu_node.get_node_or_null("Wrapper/SignpostContent")
    if not signpost:
        return

    if signpost.get_node_or_null("ModsButton"):
        return

    var quit_button = signpost.get_node_or_null("Quit")
    if not quit_button:
        return

    var button = preload("res://ui/controls/button/CustomButton.tscn").instantiate()
    button.name = "ModsButton"
    button.text = "MODS"
    signpost.add_child(button)
    signpost.move_child(button, quit_button.get_index())

    button.pressed.connect(_on_mods_button_pressed)

func _on_mods_button_pressed():
    var manager = load("res://addons/modloader/mod_manager.tscn").instantiate()
    var main = get_tree().get_root().get_node_or_null("Main")
    if main:
        main.add_child(manager)
    else:
        get_tree().get_root().add_child(manager)

func _on_game_started():
    if not stats_hooked:
        _hook_stat_system()

    for mod_id in mods:
        var mod = mods[mod_id]
        if mod.enabled and mod.instance is ModBase:
            await mod.instance._on_game_started()

    await get_tree().physics_frame
    await get_tree().process_frame

    _recalculate_all_stats()
    game_ready.emit()

func scan_and_load_mods():
    order.reverse()
    for mod_id in order:
        if mods.has(mod_id):
            _unload_mod(mods[mod_id])

    mods.clear()
    order.clear()
    
    var dir = DirAccess.open(MODS_DIR)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if dir.current_is_dir() and not file_name.begins_with("."):
                var mod_path = MODS_DIR.path_join(file_name)
                var manifest_path = mod_path.path_join("manifest.json")
                if FileAccess.file_exists(manifest_path):
                    var manifest = _parse_manifest(manifest_path)
                    if not manifest.is_empty():
                        var mod_id = file_name
                        var mod = Mod.new(mod_id, mod_path, manifest)
                        mods[mod_id] = mod

                        var mod_game_version = manifest.get("game_version", "*")
                        if mod_game_version != "*" and mod_game_version != version:
                            mod.version_mismatch = true
            file_name = dir.get_next()
    else:
        pass

    _resolve_dependencies()
    _load_mods()
    _recalculate_all_stats()

func _parse_manifest(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var content = file.get_as_text()
        file.close()
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if typeof(data) == TYPE_DICTIONARY:
                return data
            else:
                return {}
        else:
            return {}
    return {}

func _resolve_dependencies():
    var graph: Dictionary = {}
    for mod_id in mods:
        graph[mod_id] = mods[mod_id].manifest.get("dependencies", {}).keys()

    var degrees: Dictionary = {}
    for mod_id in graph:
        degrees[mod_id] = 0

    for mod_id in graph:
        for dependency in graph[mod_id]:
            if degrees.has(dependency):
                degrees[dependency] += 1

    var queue: Array = []
    for mod_id in degrees:
        if degrees[mod_id] == 0:
            queue.append(mod_id)

    order.clear()
    while not queue.is_empty():
        var mod_id = queue.pop_front()
        order.append(mod_id)

        for other_mod_id in graph:
            if mod_id in graph[other_mod_id]:
                degrees[other_mod_id] -= 1
                if degrees[other_mod_id] == 0:
                    queue.append(other_mod_id)

    if order.size() < mods.size():
        order = mods.keys()
    
func _load_mods():
    for mod_id in order:
        var mod = mods[mod_id]
        _load_mod(mod)

const ModSandbox = preload("res://addons/modloader/mod_sandbox.gd")

func _load_mod(mod: Mod):
    if not mod.enabled:
        return

    var script_path = mod.manifest.get("main_script")
    if script_path:
        var full_script_path = mod.path.path_join(script_path)
        var sandbox = ModSandbox.new(mod.id)
        var safe_code = sandbox.sandbox_script(full_script_path)
        if safe_code.is_empty():
            ModNotifications.show_notification("Mod '%s' disabled for security reasons." % mod.get_name())
            mod.enabled = false
            mod.save_enabled_state()
            return

        var script = GDScript.new()
        script.source_code = safe_code
        var err = script.reload()
        if err != OK:
            ModNotifications.show_notification("Mod '%s' crashed during loading." % mod.get_name())
            return

        mod.instance = script.new()
    else:
        mod.instance = ModBase.new()

    mod.instance.name = mod.id
    add_child(mod.instance)
    if mod.instance.has_method("_init_mod"):
        mod.instance._init_mod(mod)
    if mod.instance is ModBase:
        mod.instance.mod = mod
        mod.instance._on_mod_loaded()

    mod.stats = mod.manifest.get("stats", {})
    mod.modifiers = mod.manifest.get("modifiers", {})

    var pack_path = mod.path.path_join("assets.pck")
    if FileAccess.file_exists(pack_path):
        if ProjectSettings.load_resource_pack(pack_path):
            pass
        else:
            pass


func enable_mod(mod_id: String):
    if not mods.has(mod_id): return
    var mod = mods[mod_id]
    if not mod.enabled:
        mod.enabled = true
        mod.save_enabled_state()
        _load_mod(mod)
        _recalculate_all_stats()

func disable_mod(mod_id: String):
    if not mods.has(mod_id): return
    var mod = mods[mod_id]
    if mod.enabled:
        mod.enabled = false
        mod.save_enabled_state()
        _unload_mod(mod)

func _unload_mod(mod: Mod):
    remove_mod_dynamic_stats(mod.id)
    var regen_nodes = []
    for node_path in hooks.keys():
        var hook_data = hooks[node_path]
        var remaining_hooks = []
        var is_hooked = false
        for hook in hook_data["hooks"]:
            if hook["mod_id"] != mod.id:
                remaining_hooks.append(hook)
            else:
                is_hooked = true
        
        
        if is_hooked:
            hooks[node_path]["hooks"] = remaining_hooks
            regen_nodes.append(node_path)

    for node_path in regen_nodes:
        var node = get_node_or_null(node_path)
        if not is_instance_valid(node): continue

        if hooks[node_path]["hooks"].is_empty():
            var original_script = hooks[node_path]["original_script"]
            node.set_script(original_script)
            hooks.erase(node_path)
        else:
            _generate_and_apply_hook_script(node)

    if is_instance_valid(mod.instance):
        if mod.instance is ModBase:
            mod.instance._on_mod_unloaded()
        mod.instance.queue_free()

    var pack_path = mod.path.path_join("assets.pck")
    if FileAccess.file_exists(pack_path):
        pass

    _recalculate_all_stats()

func _recalculate_all_stats():
    if is_instance_valid(Global.game) and is_instance_valid(Global.game.player):
        if not is_instance_valid(Global.game.player.health_component):
            return
        if not is_instance_valid(Global.game.player.hitbox_component):
            return

        var stats_obj = Global.manager.player_stats
        for p in stats_obj.get_property_list():
            if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "script":
                var _dummy = stats_obj.get(p.name)

        Global.game.player.update_node()
    else:
        pass

func add_stat(mod_id: String, stat: String, value):
    if not dyn_stats.has(stat):
        dyn_stats[stat] = {}
    dyn_stats[stat][mod_id] = value

func add_modifier(mod_id: String, stat: String, value):
    if not dyn_mods.has(stat):
        dyn_mods[stat] = {}
    dyn_mods[stat][mod_id] = value

func remove_mod_dynamic_stats(mod_id: String):
    for stat in dyn_stats:
        if dyn_stats[stat].has(mod_id):
            dyn_stats[stat].erase(mod_id)
    for stat in dyn_mods:
        if dyn_mods[stat].has(mod_id):
            dyn_mods[stat].erase(mod_id)


func _modded_calc_add_stat_hook(stat_key: String, original_value: float) -> float:
    var static_val = 0.0
    for mod_id in mods:
        var mod = mods[mod_id]
        if mod.enabled:
            static_val += mod.stats.get(stat_key, 0.0)
    
    var dyn_val = 0.0
    if dyn_stats.has(stat_key):
        for mod_id in dyn_stats[stat_key]:
            dyn_val += dyn_stats[stat_key][mod_id]

    var final_value = original_value + static_val + dyn_val
    return final_value

func _modded_calc_mult_stat_hook(stat_key: String, original_value: float) -> float:
    var static_val = 1.0
    for mod_id in mods:
        var mod = mods[mod_id]
        if mod.enabled:
            static_val *= mod.modifiers.get(stat_key, 1.0)
    
    var dyn_val = 1.0
    if dyn_mods.has(stat_key):
        for mod_id in dyn_mods[stat_key]:
            dyn_val *= dyn_mods[stat_key][mod_id]

    return original_value * static_val * dyn_val

func add_hook(mod_id: String, node: Node, hook: Hook):
    var details = {
        "type": "hook",
        "pre": hook.pre_callback,
        "post": hook.post_callback
    }
    if hook.replacement_callback.is_valid():
        details["type"] = "replace"
        details["callable"] = hook.replacement_callback
    
    _add_hook(mod_id, node, hook.method, details)

func _add_hook(mod_id: String, node: Node, method_name: String, details: Dictionary):
    if not is_instance_valid(node) or not node.get_script():
        return

    var node_path = node.get_path() if not Engine.has_singleton(node.name) else node.name
    var hook_info = details
    if mod_id == "modloader_internal":
        hook_info["mod_instance"] = self
    else:
        hook_info["mod_instance"] = mods[mod_id].instance
    hook_info["method"] = method_name

    if not hooks.has(node_path):
        hooks[node_path] = { "original_script": node.get_script(), "hooks": [hook_info] }
    else:
        var existing_hooks = hooks[node_path]["hooks"]
        var new_hooks = []
        var replaced = false
        for h in existing_hooks:
            if h["method"] == method_name and h["mod_instance"] == hook_info["mod_instance"]:
                new_hooks.append(hook_info)
                replaced = true
            else:
                new_hooks.append(h)
        if not replaced:
            new_hooks.append(hook_info)
        hooks[node_path]["hooks"] = new_hooks
    
    _generate_and_apply_hook_script(node)

func _generate_and_apply_hook_script(node: Node):
    var node_path = node.get_path() if not Engine.has_singleton(node.name) else node.name
    if not hooks.has(node_path): 
        return

    var hook_data = hooks[node_path]
    var original_script: GDScript = hook_data["original_script"]
    var script_hooks: Array = hook_data["hooks"]

    var script_lines: Array = []
    script_lines.append("extends \"%s\"" % original_script.resource_path)
    script_lines.append("")
    
    var mod_refs: Dictionary = {}
    var hook_idx = 0
    for hook in script_hooks:
        var mod_instance = hook["mod_instance"]
        var var_name = "_mod_ref_%d" % hook_idx
        mod_refs[var_name] = mod_instance
        script_lines.append("var %s" % var_name)
        hook["var_name"] = var_name
        hook_idx += 1

    var mod_methods: Dictionary = {}
    for hook in script_hooks:
        var method = hook["method"]
        if not mod_methods.has(method):
            mod_methods[method] = []
        mod_methods[method].append(hook)

    for method_name in mod_methods:
        var method_hooks: Array = mod_methods[method_name]
        var sig_data = _get_method_signature(original_script, method_name)
        var signature = sig_data["signature"]
        var args: Array = sig_data["args_list"]
        var arg_str = ", ".join(args)

        script_lines.append("\nfunc %s:" % signature)

        var replacement = null
        for h in method_hooks:
            if h["type"] == "replace":
                replacement = h
                break

        if replacement:
            var var_name = replacement["var_name"]
            var replace_name = replacement["callable"].get_method()
            script_lines.append("    return %s.%s(%s)" % [var_name, replace_name, arg_str])
        else:
            script_lines.append("    var args = [%s]" % arg_str)
            script_lines.append("    var skip_original = false")
            
            for hook in method_hooks:
                if hook["pre"].is_valid():
                    var var_name = hook["var_name"]
                    var pre_name = hook["pre"].get_method()
                    script_lines.append("    var pre_result = %s.%s(args)" % [var_name, pre_name])
                    script_lines.append("    if pre_result is Dictionary:")
                    script_lines.append("        if pre_result.has(\"skip_original\"):")
                    script_lines.append("            skip_original = pre_result.skip_original")
                    script_lines.append("        if pre_result.has(\"args\"):") 
                    script_lines.append("            args = pre_result.args")

            script_lines.append("")
            script_lines.append("    var return_value = null")
            script_lines.append("    if not skip_original:")
            
            if sig_data["is_void"]:
                script_lines.append("        super.callv(\"" + method_name + "\", args)")
            else:
                script_lines.append("        return_value = super.callv(\"" + method_name + "\", args)")
            
            script_lines.append("")
            
            for hook in method_hooks:
                if hook["post"].is_valid():
                    var var_name = hook["var_name"]
                    var post_name = hook["post"].get_method()
                    script_lines.append("    var post_result = %s.%s(args, return_value)" % [var_name, post_name])
                    script_lines.append("    if post_result != null:")
                    script_lines.append("        return_value = post_result")
            
            script_lines.append("")
            script_lines.append("    return return_value")

    var script_text = "\n".join(script_lines)
    var new_script = GDScript.new()
    new_script.source_code = script_text
    var err = new_script.reload()
    if err != OK:
        return

    var is_autoload = Engine.has_singleton(node.name)
    var parent = null if is_autoload else node.get_parent()
    var index = -1 if is_autoload else node.get_index()
    var was_inside_tree = node.is_inside_tree()

    if was_inside_tree and parent and not is_autoload:
        parent.remove_child(node)

    node.set_script(new_script)
    
    for var_name in mod_refs:
        node.set(var_name, mod_refs[var_name])

    if was_inside_tree and parent and not is_autoload:
        parent.add_child(node)
        parent.move_child(node, index)


func _get_method_signature(script: GDScript, method_name: String) -> Dictionary:
    for method in script.get_script_method_list():
        if method.name == method_name:
            var args = []
            for arg_info in method.args:
                args.append(arg_info.name)
            var is_void = (method.return.type == TYPE_NIL)
            return { "signature": method_name + "(" + ", ".join(args) + ")", "args_list": args, "is_void": is_void }

    match method_name:
        "_physics_process", "_process", "_ready", "_input", "_unhandled_input", "_unhandled_key_input":
            var arg_map = {
                "_physics_process": ["delta"], "_process": ["delta"], "_ready": [],
                "_input": ["event"], "_unhandled_input": ["event"], "_unhandled_key_input": ["event"]
            }
            var args = arg_map.get(method_name, [])
            var signature = method_name + "(" + ", ".join(args) + ")"
            return { "signature": signature, "args_list": args, "is_void": true }
        _:
            if method_name.begins_with("_"):
                pass
            else:
                pass
            return { "signature": method_name + "()", "args_list": [], "is_void": true }

const HookedPlayerStats = preload("res://addons/modloader/hooked_player_stats.gd")

func _hook_stat_system():
    var orig_stats = Global.manager.player_stats
    if not is_instance_valid(orig_stats):
        return

    var new_stats = HookedPlayerStats.new(
        Global.manager.trait_upgrades,
        Global.manager.item_upgrades,
        Global.manager.trinket_upgrades,
        Global.manager.curio_upgrades,
        Global.manager.buff_upgrades
    )
    
    new_stats.level = orig_stats.level
    new_stats.xp = orig_stats.xp
    new_stats.total_xp = orig_stats.total_xp

    Global.manager.player_stats = new_stats
    stats_hooked = true
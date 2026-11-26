extends RefCounted


static func configure(window: Window) -> void:
    # Keep child dialogs in the parent's viewport when its title bar is dragged.
    window.gui_embed_subwindows = true
    window.visibility_changed.connect(_dismiss_if_parent_hidden.bind(window), CONNECT_DEFERRED)


static func _dismiss_if_parent_hidden(window: Window) -> void:
    if window.visible:
        return

    for child in window.get_children():
        if child is AcceptDialog and child.visible:
            child.hide()

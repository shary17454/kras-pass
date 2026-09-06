extends Screen

var _login: Button
var _logout: Button
var _delete: Button
var _status: Label


func build() -> void:
	back_target = "profile"
	title(Loc.t("account.title"))
	_login = add_menu_button(Loc.t("account.sign_in"), AppleAccount.sign_in)
	_logout = add_menu_button(Loc.t("account.sign_out"), AppleAccount.sign_out)
	_delete = add_menu_button(Loc.t("account.delete"), _confirm_deletion)
	_status = UIKit.label("", UIKit.SIZE_SMALL)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	AppleAccount.changed.connect(_update)
	_update()


func _update() -> void:
	_login.visible = not AppleAccount.signed_in
	_login.disabled = AppleAccount.busy or not AppleAccount.available()
	_logout.visible = AppleAccount.signed_in
	_delete.visible = AppleAccount.signed_in
	_logout.disabled = AppleAccount.busy
	_delete.disabled = AppleAccount.busy
	var key := AppleAccount.status_key
	if key.is_empty():
		key = "account.connected" if AppleAccount.signed_in else "account.disconnected"
	if AppleAccount.has_all_games() and (key.is_empty() or key == "account.connected"):
		key = "account.owner_active"
	if not AppleAccount.available():
		key = "account.ios_only"
	_status.text = Loc.t(key)


func _confirm_deletion() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = Loc.t("account.delete")
	dialog.dialog_text = Loc.t("account.delete_confirm")
	dialog.ok_button_text = Loc.t("account.delete")
	dialog.cancel_button_text = Loc.t("common.cancel")
	dialog.confirmed.connect(func(): AppleAccount.delete_account(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 260))

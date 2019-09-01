tool
extends EditorPlugin

#Do not draw brush figure over same TileMap tile, until mouse is moved to another tile cell
#It may reduce processor load, but you may find it not comfortable to use
const OPTIMIZE = false

const TileMapBrush = preload('TileMapBrush.gd')

var tilemap : TileMapBrush


func _enter_tree():
	add_custom_type("TileMapBrush", "TileMap", TileMapBrush, preload("icon.png"))
	
#called every time, when scene loses focus
#Supposed to be clear() - vritual method, but it calls only on new scene gets created(and it won't work on scene get closed)
func get_state():
	tilemap = null

func handles(object : Object):
	#check, if TileMapBrushPlugin should handle this object
	#called on object selection
	#won't work properly with multiple objects selection definetely

	return object is TileMapBrush and (object as Node2D).is_visible_in_tree()


func edit(object : Object):
	#save currently selected object in scene
	tilemap = object as TileMapBrush


enum ButtonStatus {RELEASED, PRESSED}
var drawStatus = ButtonStatus.RELEASED
var eraseStatus = ButtonStatus.RELEASED

func forward_canvas_gui_input (event : InputEvent):
	if !tilemap:
		#no object to handle is selected in scene tree
		return false
		
	#Save if mouse is pressed, or unpressed;
	#It will be handled in _physics_process between press and release actions
	if event is InputEventMouseButton:
		var buttonEvent = event as InputEventMouseButton
		if buttonEvent.pressed:
			if buttonEvent.button_index == BUTTON_LEFT:
				drawStatus = ButtonStatus.PRESSED
			elif buttonEvent.button_index == BUTTON_RIGHT:
				eraseStatus = ButtonStatus.PRESSED
		else:
			if buttonEvent.button_index == BUTTON_LEFT:
				drawStatus = ButtonStatus.RELEASED
			elif buttonEvent.button_index == BUTTON_RIGHT:
				eraseStatus = ButtonStatus.RELEASED
		processMouse() #no need to wait next _physics_process execution - needs for some timing cases
		
	elif event is InputEventMouseMotion:
		if drawStatus == ButtonStatus.PRESSED:
			pass #tilemap.drawPos((event as InputEventMouseMotion).global_position)
		processMouse()
			
	return false



var lastPosition = {
	'draw' : false,
	'erase' : false
}

func _physics_process (delta):
	if !tilemap:
		return
	
	#Send draw or erase requests to active TileMapBrush object, depending on which mouse button pressed
	processMouse()
	#It was decided to move TileMapBrush's _physics_process() to processDraw(), with calling only active object
	tilemap.processDraw()


func processMouse ():
	if drawStatus == ButtonStatus.PRESSED:
		tilemap.draw()
		if OPTIMIZE:
			var pos = tilemap.get_map_mouse_position()
			if lastPosition.draw is bool or pos != lastPosition.draw:
				lastPosition.draw = pos
	if eraseStatus == ButtonStatus.PRESSED:
		tilemap.erase()
		if OPTIMIZE:
			var pos = tilemap.get_map_mouse_position()
			if lastPosition.erase is bool or pos != lastPosition.erase:
				lastPosition.erase = pos


func _exit_tree():
    remove_custom_type("TileMapBrush")



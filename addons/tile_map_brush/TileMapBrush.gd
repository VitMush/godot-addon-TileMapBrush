tool
extends TileMap

enum BrushType { SQUARE, SQUARE_ROTATED, CIRCLE, LINE_H, LINE_V }

export (int, 1, 1000) var drawSize = 1
export (BrushType) var drawBrushType = BrushType.SQUARE

export (int, 1, 1000) var eraseSize = 1
export (BrushType) var eraseBrushType = BrushType.SQUARE

export var RespectAutotiling: bool = false

#Arrays hold Vector2, but it's easier to know when value is empty with arrays
var drawWait : Array = []
var drawNext : Array = []


func draw():
	#Do not draw right now, save current tile position for _physic_process (because TileMap haven't draw a tile yet)
	#Method, originally, called from TileMapBrushPlugin, on pressing Left Mouse Key
	var pos = get_map_mouse_position()
	drawWait.push_back(pos)
	
	
func erase():
	#Draw a tile with general method, but with tile_index = -1 (which means empty)
	#Method, originally, called from TileMapBrushPlugin, on pressing Right Mouse Key
	var pos = get_map_mouse_position()
	var info = get_cell_info(pos)
	info.tile = -1
	drawBrush(pos, info, eraseBrushType, eraseSize)


func processDraw():
	#method get called from TileMapBrushPlugin in _physics_process
	#another solution: process in self._physics_process, like
	#if not Engine.editor_hint:
	#	return
	
	#drawNext field holds draw request cells for next frame(in case TileMap haven't draw tiles yet)
	#not too often case; so, 1 iteration should be enough, then request is removed
	while !drawNext.empty():
		var pos = drawNext.pop_front()
		if get_cellv(pos) != -1:
			#draw other tiles with same property of tile drawn by TileMap
			drawBrush(pos, get_cell_info(pos), drawBrushType, drawSize)
		#else, drawNext stack get freed 
		#(not drawn, probably because mouse is faster, than _physics_process delta - wrong cell position saved)

	#drawWait field holds draw requests, saved in self.draw()
	while !drawWait.empty():
		var pos = drawWait.pop_front()
		if get_cellv(pos) != -1:
			#draw other tiles with same property TileMap drawn a tile
			drawBrush(pos, get_cell_info(pos), drawBrushType, drawSize)
		else:
			#save draw request for next frame
			drawNext.push_back(pos)

func drawBrush (pos : Vector2, cell : Dictionary, brushType, size : int):
	match brushType:
		BrushType.SQUARE:
			drawSquare(pos, cell, size)
		BrushType.SQUARE_ROTATED:
			drawSquareRotated(pos, cell, size)
		BrushType.CIRCLE:
			drawCircle(pos, cell, size)
		BrushType.LINE_H:
			drawLineH(pos, cell, size)
		BrushType.LINE_V:
			drawLineV(pos, cell, size)


func drawSquare (pos, cell : Dictionary, brushSize : float):
	var bound = brushSize / 2
	for x in range(pos.x - floor(bound), pos.x + round(bound)):
		for y in range(pos.y - floor(bound), pos.y + round(bound)): 
			setCell(x, y, cell.tile, cell.flip_x, cell.flip_y, cell.transpose, cell.autotile_coord)


func drawSquareRotated (pos, cell : Dictionary, brushSize : float):
	var bound = round(sqrt(pow(brushSize, 2) * 2) / 2)

	var topLeft = Vector2(pos.x - bound, pos.y)
	var topRight = Vector2(pos.x, pos.y - bound)
	var bottomLeft = Vector2(pos.x, pos.y + bound)
	var bottomRight = Vector2(pos.x + bound, pos.y)

	for x in range(pos.x - bound, pos.x + bound):
		for y in range(pos.y - bound, pos.y + bound):
			if (1 == sign((topRight.x - topLeft.x) * (y - topLeft.y) - (topRight.y - topLeft.y) * (x - topLeft.x)) 
					and -1 == sign((bottomLeft.x - topLeft.x) * (y - topLeft.y) - (bottomLeft.y - topLeft.y) * (x - topLeft.x))
					and -1 == sign((bottomRight.x - bottomLeft.x) * (y - bottomLeft.y) - (bottomRight.y - bottomLeft.y) * (x - bottomLeft.x))
					and -1 == sign((topRight.x - bottomRight.x) * (y - bottomRight.y) - (topRight.y - bottomRight.y) * (x - bottomRight.x))):
				setCell(x, y, cell.tile, cell.flip_x, cell.flip_y, cell.transpose, cell.autotile_coord)


func drawSquareRotatedOld (pos, cell : Dictionary, brushSize : float):
	var bound = ceil(brushSize / 2 + 3)
	for x in range(pos.x - bound, pos.x + bound):
		for y in range(pos.y - bound, pos.y + bound):
			if abs(x - pos.x) + abs(y - pos.y) <= brushSize / 2 + 2:
				setCell(x, y, cell.tile, cell.flip_x, cell.flip_y, cell.transpose, cell.autotile_coord)


func drawCircle (pos, cell : Dictionary, brushSize : float):
	var bound = round(brushSize / 2)
	for x in range(pos.x - bound, pos.x + bound + 1):
		for y in range(pos.y - bound, pos.y + bound + 1):
			if sqrt((pow(x - pos.x, 2) as float) + (pow(y - pos.y, 2) as float)) <= brushSize / 2:
				setCell(x, y, cell.tile, cell.flip_x, cell.flip_y, cell.transpose, cell.autotile_coord)


func drawLineH (pos, cell : Dictionary, brushSize):
	for x in range(pos.x - (brushSize / 2), round(pos.x as float + (brushSize as float / 2))):
		setCell(x, pos.y, cell.tile, cell.flip_x, cell.flip_y, cell.transpose, cell.autotile_coord)


func drawLineV (pos, cell : Dictionary, brushSize):
	for y in range(pos.y - (brushSize / 2), round(pos.y as float + (brushSize as float / 2))):
		setCell(pos.x, y, cell.tile, cell.flip_x, cell.flip_y, cell.transpose, cell.autotile_coord)

func get_cell_info(pos : Vector2):
	return {
		'tile' : get_cell(pos.x, pos.y),
		'flip_x' : is_cell_x_flipped(pos.x, pos.y),
		'flip_y' : is_cell_y_flipped(pos.x, pos.y),
		'transpose' : is_cell_transposed(pos.x, pos.y),
		'autotile_coord' : get_cell_autotile_coord(pos.x, pos.y)
	}

func get_map_mouse_position():
	#returns position on TileMap Grid
	return world_to_map(get_viewport().get_mouse_position())

#Calls regular set_cell method and immediatelly updates the bitmask area of the cell,
# allowing for correct autotiling if set and Respect Autotiling is checked. 
# dev note: Might impact performance notably if brush size > 100, at brush size 10 no performance notable on my setup
func setCell(x: int, y: int, tile: int, flipx: bool, flipy: bool, transpose: bool, autotile_coord: Vector2):
	set_cell(x, y, tile, flipx, flipy, transpose, autotile_coord)
	if RespectAutotiling:
		update_bitmask_area(Vector2(x,y))

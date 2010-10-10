package com.nitrome.phys{
	import flash.geom.Rectangle;
	
	/* The HashMap does what is says on the tin.
	*
	* It requires the scale to exceed the largest object it will be dealing with
	* Therefore it is useful for lots of reasonably sized objects that don't differ
	* in size too much - otherwise I'd be implementing a QuadTree
	* 
	* edit:
	*
	* This is now a variation on a HashMap - I've chosen to test more cells as opposed to register
	* objects to more cells. This means I will only ever capture an object when looking for it once.
	* I'm doing this by making the cells overlap and registering objects by their top left corner
	*
	* In this I'm hoping for a trade off of better movement and less to look at when debugging.
	* There's also less objects to sort through on an area test - no duplicates
	*/
	
	public class HashMap{
		
		public var width:int;
		public var height:int;
		public var scale:Number;
		public var invScale:Number;
		public var cells:Vector.<Vector.<Cell>>;
		public var bounds:Rectangle;
		
		/* Beyond a certain point, floating point math starts to fail because binary can't represent it.
		 * This causes errors in testing areas for Colliders - so we ignore values beyond a number of digits */
		public static const INTERVAL_TOLERANCE:Number = 0.00000001;
		
		public function HashMap(width:int, height:int, scale:Number, bounds:Rectangle){
			this.width = width;
			this.height = height;
			this.scale = scale;
			this.bounds = bounds;
			invScale = 1.0 / scale;
			cells = new Vector.<Vector.<Cell>>;
			var r:int, c:int;
			for(r = 0; r < height; r++){
				cells[r] = new Vector.<Cell>();
				for(c = 0; c < width; c++){
					cells[r][c] = null;
				}
			}
		}
		
		/* Add the Collider to the appropriate Cells in the hash map
		*
		* It is assumed that the scale of the Cells will always be equal to or larger than the Colliders,
		* which allows assignment to be a far quicker operation */
		public function addCollider(collider:Collider):void{
			var mapX:int = collider.x * invScale;
			var mapY:int = collider.y * invScale;
			if(!cells[mapY][mapX]){
				cells[mapY][mapX] = new Cell(mapX, mapY);
			}
			cells[mapY][mapX].colliders.push(collider);
			collider.cell = cells[mapY][mapX];
		}
		
		/* Remove the Collider from the HashMap */
		public function removeCollider(collider:Collider):void{
			collider.cell.colliders.splice(collider.cell.colliders.indexOf(collider), 1);
			if(collider.cell.colliders.length == 0){
				cells[collider.cell.y][collider.cell.x] = null;
			}
			collider.cell = null;
		}
		
		/* Moves the Collider within the HashMap - recalculating its Cell occupation
		* It requires knowledge of the distance moved in order to execute changes
		*
		* This method only performs assignment, it does not calculate collision */
		public function updateCollider(collider:Collider):void{
			var mapX:int = collider.x * invScale;
			var mapY:int = collider.y * invScale;
			if(collider.cell.x != mapX || collider.cell.y != mapY){
				collider.cell.colliders.splice(collider.cell.colliders.indexOf(collider), 1);
				if(collider.cell.colliders.length == 0){
					cells[collider.cell.y][collider.cell.x] = null;
				}
				if(!cells[mapY][mapX]){
					cells[mapY][mapX] = new Cell(mapX, mapY);
				}
				cells[mapY][mapX].colliders.push(collider);
				collider.cell = cells[mapY][mapX];
			}
		}
		
		/* Return a Collider that contains the coord x,y */
		public function getColliderAt(x:Number, y:Number):Collider{
			// Colliders register to their upper left most point, so in capturing a point
			// we need to test 4 cells - because they overlap
			var i:int;
			var mapX:int, mapY:int;
			mapX = x * invScale;
			mapY = y * invScale;
			if(mapY - 1 >= 0 && mapX - 1 >= 0 && cells[mapY - 1][mapX - 1]){
				for(i = 0; i < cells[mapY - 1][mapX - 1].colliders.length; i++){
					if(cells[mapY - 1][mapX - 1].colliders[i].contains(x, y)){
						return cells[mapY - 1][mapX - 1].colliders[i];
					}
				}
			}
			if(mapY - 1 >= 0 && cells[mapY - 1][mapX]){
				for(i = 0; i < cells[mapY - 1][mapX].colliders.length; i++){
					if(cells[mapY - 1][mapX].colliders[i].contains(x, y)){
						return cells[mapY - 1][mapX].colliders[i];
					}
				}
			}
			if(mapX - 1 >= 0 && cells[mapY][mapX - 1]){
				for(i = 0; i < cells[mapY][mapX - 1].colliders.length; i++){
					if(cells[mapY][mapX - 1].colliders[i].contains(x, y)){
						return cells[mapY][mapX - 1].colliders[i];
					}
				}
			}
			if(cells[mapY][mapX]){
				for(i = 0; i < cells[mapY][mapX].colliders.length; i++){
					if(cells[mapY][mapX].colliders[i].contains(x, y)){
						return cells[mapY][mapX].colliders[i];
					}
				}
			}
			return null;
		}
		
		/* Return all the Colliders that touch the rectangle "area" */
		public function getCollidersIn(area:Rectangle, ignore:Collider = null):Vector.<Collider>{
			var result:Vector.<Collider> = new Vector.<Collider>();
			var collider:Collider;
			var r:int, c:int, i:int;
			var minX:int = area.x * invScale;
			var minY:int = area.y * invScale;
			var maxX:int = minX + Math.ceil(area.width * invScale);
			var maxY:int = minY + Math.ceil(area.height * invScale);
			// because the area tested involves overlaps, we step the minimum backwards
			minX--;minY--;
			for(r = minY; r <= maxY; r++){
				for(c = minX; c <= maxX; c++){
					if(c >= 0 && r >= 0 && c < width && r < height && cells[r][c]){
						for(i = 0; i < cells[r][c].colliders.length; i++){
							
							collider = cells[r][c].colliders[i];
							
							// floating point error causes a lot of false positives, so that's
							// why I'm using a tolerance value to ignore those drifting values
							// at the end of the Number datatype
							if(collider != ignore &&
								collider.x + collider.width - INTERVAL_TOLERANCE > area.x &&
								collider.y + collider.height - INTERVAL_TOLERANCE > area.y &&
								area.x + area.width - INTERVAL_TOLERANCE > collider.x &&
								area.y + area.height - INTERVAL_TOLERANCE > collider.y
							){
								result.push(collider);
							}
							
						}
					}
				}
			}
			return result;
		}
	}
}
package com.nitrome.phys {

	public class Cell {
		
		public var x:int;
		public var y:int;
		public var colliders:Vector.<Collider>;

		public function Cell(x:int, y:int) {
			this.x = x;
			this.y = y;
			colliders = new Vector.<Collider>();
		}
	}
}
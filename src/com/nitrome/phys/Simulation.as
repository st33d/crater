package com.nitrome.phys{
	import flash.display.Graphics;
	import flash.geom.Rectangle;
	
	public class Simulation{
		
		public var bounds:Rectangle;
		public var hashMap:HashMap;
		public var colliders:Vector.<Collider>;
		public var shockwaves:Vector.<Shockwave>;
		
		public var debug:Graphics;
		
		protected static var i:int;
		
		public function Simulation(bounds:Rectangle, hashMapScale:Number){
			this.bounds = bounds;
			hashMap = new HashMap(Math.ceil(bounds.width / hashMapScale), Math.ceil(bounds.height / hashMapScale), hashMapScale, bounds);
			colliders = new Vector.<Collider>();
			shockwaves = new Vector.<Shockwave>();
		}
		
		public function main():void{
			if(shockwaves.length){
				for(i = 0; i < shockwaves.length; i++){
					shockwaves[i].execute();
				}
				if(debug){
					for(i = 0; i < shockwaves.length; i++){
						shockwaves[i].draw(debug);
					}
				}
				shockwaves.length = 0;
			}
			for(i = 0; i < colliders.length; i++){
				if(colliders[i].awake) colliders[i].main();
			}
			if(debug){
				for(i = 0; i < colliders.length; i++){
					colliders[i].draw(debug);
				}
			}
		}
		
		/* Creates a new Collider in the simulation */
		public function addCollider(x:Number, y:Number, width:Number, height:Number):Collider{
			// force the collider to be in the bounds of the map
			if(x < bounds.x) x = bounds.x;
			if(y < bounds.y) y = bounds.y;
			if(x + width > bounds.x + bounds.width) x = (bounds.x + bounds.width) - width;
			if(y + height > bounds.y + bounds.height) y = (bounds.y + bounds.height) - height;
			var collider:Collider = new Collider(x, y, width, height, hashMap, true);
			colliders.push(collider);
			if(hashMap.getCollidersIn(collider).length){
				collider.state = Collider.FLOAT;
			} else {
				hashMap.addCollider(collider);
			}
			trace(colliders.length);
			return collider;
		}
		
		/* Removes a Collider from the simulation */
		public function removeCollider(collider:Collider):void{
			collider.divorce();
			colliders.splice(colliders.indexOf(collider), 1);
			hashMap.removeCollider(collider);
		}
		
		/* Adds a shockwave effect to be applied on the next frame */
		public function addShockwave(x:Number, y:Number, radius:Number, velocity:Number, step:Number):void{
			shockwaves.push(new Shockwave(x, y, radius, velocity, step, hashMap));
		}
	}
}
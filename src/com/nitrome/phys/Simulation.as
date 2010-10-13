package com.nitrome.phys{
	import flash.display.Graphics;
	import flash.geom.Rectangle;
	
	/**
	 * Management object for a physics simulation
	 *
	 * Colliders are generated with this object to ensure that they are propagated to the HashMap or
	 * set to FLOAT if overlapping
	 *
	 * @author Aaron Steed, nitrome.com
	 */
	public class Simulation{
		
		public var bounds:Rectangle;
		public var hashMap:HashMap;
		public var colliders:Vector.<Collider>;
		public var floaters:Vector.<Collider>;
		public var shockwaves:Vector.<Shockwave>;
		
		public var debug:Graphics;
		
		protected static var i:int;
		
		public function Simulation(bounds:Rectangle, hashMapScale:Number){
			this.bounds = bounds;
			hashMap = new HashMap(Math.ceil(bounds.width / hashMapScale), Math.ceil(bounds.height / hashMapScale), hashMapScale, bounds);
			colliders = new Vector.<Collider>();
			shockwaves = new Vector.<Shockwave>();
			floaters = new Vector.<Collider>();
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
			if(floaters.length) floaters.filter(floaterCallBack);
			if(debug){
				for(i = 0; i < colliders.length; i++){
					colliders[i].draw(debug);
				}
			}
		}
		
		private function floaterCallBack(item:Collider, index:int, list:Vector.<Collider>):Boolean{
			return item.state == Collider.FLOAT;
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
				floaters.push(collider);
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
		
		/* Picks out a collider from all colliders available by also checking the floaters list */
		public function getColliderAt(x:Number, y:Number):Collider{
			for(var i:int = 0; i < floaters.length; i++){
				if(floaters[i].contains(x, y)) return floaters[i];
			}
			return hashMap.getColliderAt(x, y);
		}
	}
}
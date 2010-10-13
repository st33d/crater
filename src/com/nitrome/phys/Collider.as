package com.nitrome.phys {

	import flash.display.Graphics;
	import flash.geom.Rectangle;
	
	/**
	 * A crate-like collision object.
	 *
	 * Collisions are handled recursively, allowing the object to push queues of crates.
	 *
	 * The Collider has several states to reflect how it may need to be handled.
	 *
	 * Colliders introduced to the physics simulation overlapping other Colliders will go into a FLOAT state
	 * to allow them to drift up to the top of whatever stack they are sitting on.
	 *
	 * @author Aaron Steed, nitrome.com
	 */
	public class Collider extends Rectangle {
		
		public var state:int;
		public var active:Boolean;
		public var hashMap:HashMap;
		public var vx:Number;
		public var vy:Number;
		public var parent:Collider;
		public var children:Vector.<Collider>;
		public var cell:Cell;
		public var awake:int;
		public var userData:*;
		
		/* Establishes a minimum movement policy */
		public static const TOLERANCE:Number = 0.0001;
		
		/* Echoing Box2D, colliders sleep when inactive to prevent method calls that aren't needed */
		public static var AWAKE_DELAY:int = 3;
		
		private static var tempCollider:Collider;
		
		// states
		public static const STACK:int = 0;
		public static const FLOAT:int = 1;
		public static const DRAGGED:int = 2;
		
		public static const GRAVITY:Number = 0.5;
		public static const AIR_DAMPING:Number = 0.98;
		public static const SKATE_DAMPING:Number = 0.9;
		public static const FLOAT_SPEED:Number = -Game.SCALE * 0.25;
		
		public function Collider(x:Number=0, y:Number=0, width:Number=0, height:Number=0, hashMap:HashMap = null, active:Boolean = false) {
			super(x, y, width, height);
			this.hashMap = hashMap;
			this.active = active;
			state = STACK;
			vx = vy = 0;
			children = new Vector.<Collider>();
			awake = AWAKE_DELAY;
		}
		
		public function main():void{
			if(state == STACK){
				vx *= AIR_DAMPING;
				if(!parent && y + height < hashMap.bounds.y + hashMap.bounds.height) vy = vy * AIR_DAMPING + GRAVITY;
				else {
					vx *= SKATE_DAMPING;
					// this dirty hack is to deal with this random bug I'm getting with parenting -
					// for some reason, when I have a truckload of crates, I get false parenting going on
					// no idea why as yet - this is here to break this behaviour, but I consider it
					// unwanted overhead
					if(parent && parent.y > y + height + HashMap.INTERVAL_TOLERANCE){
						divorce();
					}
				}
				if(vx) moveX(vx);
				if(vy) moveY(vy);
			} else if(state == FLOAT){
				if(vx){
					vx *= AIR_DAMPING;
					x += vx;
				}
				if(vy){
					vy *= AIR_DAMPING;
					y += vy;
				}
				y += FLOAT_SPEED;
				if(x < hashMap.bounds.x) x = hashMap.bounds.x;
				if(y < hashMap.bounds.y) y = hashMap.bounds.y;
				if(x + width > hashMap.bounds.x + hashMap.bounds.width) (hashMap.bounds.x + hashMap.bounds.width) - width;
				if(y + height > hashMap.bounds.y + hashMap.bounds.height) (hashMap.bounds.y + hashMap.bounds.height) - height;
				if(hashMap.getCollidersIn(this).length == 0){
					state = STACK;
					hashMap.addCollider(this);
				}
				awake = AWAKE_DELAY;
			} else if(state == DRAGGED){
				return;
			}
			// will put the collider to sleep if it doesn't move
			if((vx > 0 ? vx : -vx) < TOLERANCE && (vy > 0 ? vy : -vy) < TOLERANCE && (awake)) awake--;
		}
		
		public function drag(vx:Number, vy:Number):void{
			moveX(vx);
			moveY(vy);
			hashMap.updateCollider(this);
		}
		
		/* =================================================================
		 * Sorting callbacks for colliding with objects in the correct order
		 * =================================================================
		 */
		public function sortLeftWards(a:Collider, b:Collider):Number{
			if(a.x < b.x) return -1;
			else if(a.x > b.x) return 1;
			return 0;
		}
		
		public function sortRightWards(a:Collider, b:Collider):Number{
			if(a.x > b.x) return -1;
			else if(a.x < b.x) return 1;
			return 0;
		}
		
		public function sortTopWards(a:Collider, b:Collider):Number{
			if(a.y < b.y) return -1;
			else if(a.y > b.y) return 1;
			return 0;
		}
		
		public function sortBottomWards(a:Collider, b:Collider):Number{
			if(a.y > b.y) return -1;
			else if(a.y < b.y) return 1;
			return 0;
		}
		
		/* add a child collider to this collider - it will move when this collider moves */
		public function addChild(collider:Collider):void{
			collider.parent = this;
			collider.vy = 0;
			children.push(collider);
		}
		
		/* remove a child collider from children */
		public function removeChild(collider:Collider):void{
			collider.parent = null;
			children.splice(children.indexOf(collider), 1);
			collider.awake = AWAKE_DELAY;
		}
		
		/* Get rid of children and parent - used to remove the collider from the game and clear current interaction */
		public function divorce():void{
			if(parent){
				parent.removeChild(this);
				vy = 0;
			}
			for (var i:int = 0; i < children.length; i++) {
				children[i].parent = null;
				children[i].vy = 0;
				children[i].awake = AWAKE_DELAY;
			}
			children.length = 0;
			awake = AWAKE_DELAY;
		}
		
		public function moveX(vx:Number):Number{
			if(Math.abs(vx) < TOLERANCE) return 0;
			var i:int;
			var obstacles:Vector.<Collider>;
			var shouldMove:Number;
			var actuallyMoved:Number;
			if(vx > 0){
				obstacles = hashMap.getCollidersIn(new Rectangle(x + width, y, vx, height), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortLeftWards);
				else if(obstacles.length == 2){
					if(obstacles[0].x > obstacles[1].x){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this){
						// because the vx may get altered over this loop, we need to still check for overlap
						if(obstacles[i].x < x + width + vx){
							
//							Game.debug.lineStyle(2, 0x00FF00);
//							Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
//							Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
//							Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
							
//							trace("push:");
//							trace(this);
//							trace(obstacles[i]);
							
							shouldMove = (x + width + vx) - obstacles[i].x;
							
							actuallyMoved = obstacles[i].moveX(shouldMove);
							if(actuallyMoved < shouldMove){
								vx -= shouldMove - actuallyMoved;
								// kill energy when recursively hitting bounds
								if(obstacles[i].vx == 0) this.vx = 0;
							}
						} else break;
					}
				}
				// now check against the edge of the map
				if(x + width + vx > hashMap.bounds.x + hashMap.bounds.width){
					vx -= (x + width + vx) - (hashMap.bounds.x + hashMap.bounds.width);
					this.vx = 0;
				}
			} else if(vx < 0){
				obstacles = hashMap.getCollidersIn(new Rectangle(x + vx, y, -vx, height), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortRightWards);
				else if(obstacles.length == 2){
					if(obstacles[0].x < obstacles[1].x){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this){
						// because the vx may get altered over this loop, we need to still check for overlap
						if(obstacles[i].x + obstacles[i].width > x + vx){
							
//							Game.debug.lineStyle(2, 0x00FF00);
//							Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
//							Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
//							Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
							
							shouldMove = (x + vx) - (obstacles[i].x + obstacles[i].width);
							actuallyMoved = obstacles[i].moveX(shouldMove);
							if(actuallyMoved > shouldMove){
								vx += actuallyMoved - shouldMove;
								// kill energy when recursively hitting bounds
								if(obstacles[i].vx == 0) this.vx = 0;
							}
						} else break;
					}
				}
				// now check against the edge of the map
				if(x + vx < hashMap.bounds.x){
					vx += hashMap.bounds.x - (x + vx);
					this.vx = 0;
				}
			}
			x += vx;
			hashMap.updateCollider(this);
			// if the collider has a parent, check it is still sitting on it
			if(parent && (x + width <= parent.x || x >= parent.x + parent.width)){
				parent.removeChild(this);
			}
			// if the collider has children, check they're still sitting on this
			if(children.length){
				for(i = children.length - 1; i > -1; i--){
					if(children[i].x + children[i].width <= x || children[i].x >= x + width){
						removeChild(children[i]);
					}
				}
			}
			awake = AWAKE_DELAY;
			return vx;
		}
		
		
		public function moveY(vy:Number):Number{
			if(Math.abs(vy) < TOLERANCE) return 0;
			var i:int;
			var obstacles:Vector.<Collider>;
			var shouldMove:Number;
			var actuallyMoved:Number;
			if(vy > 0){
				obstacles = hashMap.getCollidersIn(new Rectangle(x, y + height, width, vy), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortTopWards);
				else if(obstacles.length == 2){
					if(obstacles[0].y > obstacles[1].y){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this && obstacles[i] != parent){
						
						// this code commented out because the current simulation doesn't need
						// objects that push down yet - so I might as well leave them out
						
						// because the vy may get altered over this loop, we need to still check for overlap
//						if(obstacles[i].y < y + height + vy){
//							shouldMove = (y + height + vy) - obstacles[i].y;
//							actuallyMoved = obstacles[i].moveY(shouldMove);
//							if(actuallyMoved < shouldMove){
//								vy -= shouldMove - actuallyMoved;
//								// kill energy when recursively hitting bounds
//								if(obstacles[i].vy == 0) this.vy = 0;
//							}
//							// make this Collider a child of the obstacle
//							if(state == STACK && (!parent || (parent && obstacles[i] != parent))){
//								if(parent) parent.removeChild(this);
//								obstacles[i].addChild(this);
//							}
//						} else break;
						
//						Game.debug.lineStyle(2, 0x00FF00);
//						Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
//						Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
//						Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
						
						
						vy = obstacles[i].y - (y + height);
						if(state == STACK && (!parent || (parent && obstacles[i] != parent))){
							if(parent) parent.removeChild(this);
							obstacles[i].addChild(this);
						}
						break;
						
						
					}
				}
				// now check against the edge of the map
				if(y + height + vy > hashMap.bounds.y + hashMap.bounds.height){
					vy -= (y + height + vy) - (hashMap.bounds.y + hashMap.bounds.height);
					this.vy = 0;
				}
			} else if(vy < 0){
				obstacles = hashMap.getCollidersIn(new Rectangle(x, y + vy, width, -vy), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortBottomWards);
				else if(obstacles.length == 2){
					if(obstacles[0].y < obstacles[1].y){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this){
						// because the vy may get altered over this loop, we need to still check for overlap
						if(obstacles[i].y + obstacles[i].height > y + vy){
							
//							Game.debug.lineStyle(2, 0x00FF00);
//							Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
//							Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
//							Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
							
							shouldMove = (y + vy) - (obstacles[i].y + obstacles[i].height);
							actuallyMoved = obstacles[i].moveY(shouldMove);
							if(actuallyMoved > shouldMove){
								vy += actuallyMoved - shouldMove;
								// kill energy when recursively hitting bounds
								if(obstacles[i].vy == 0) this.vy = 0;
							}
							// make the obstacle a child of this Collider
							if(obstacles[i].state == STACK && (!obstacles[i].parent || (obstacles[i].parent && obstacles[i].parent != this))){
								if(obstacles[i].parent) obstacles[i].parent.removeChild(obstacles[i]);
								addChild(obstacles[i]);
							}
						} else break;
					}
				}
				// now check against the edge of the map
				if(y + vy < hashMap.bounds.y){
					vy += hashMap.bounds.y - (y + vy);
					this.vy = 0;
				}
			}
			y += vy;
			hashMap.updateCollider(this);
			// move children - ie: blocks stacked on top of this Collider
			// children should not be moved when travelling up - this Collider is already taking care of that
			// by pushing them
			if(vy > 0){
				for(i = 0; i < children.length; i++){
					children[i].moveY(vy);
				}
			}
			awake = AWAKE_DELAY;
			return vy;
		}
		
		/* Draw debug diagram */
		public function draw(gfx:Graphics):void{
			gfx.lineStyle(2, 0xFFFF00);
			gfx.drawRect(x, y, width, height);
			if(awake){
				gfx.drawRect(x + 5, y + 5, width - 10, height - 10);
			}
			if(parent != null){
				gfx.moveTo(x + width * 0.5, y + height * 0.5);
				gfx.lineTo(parent.x, parent.y);
			}
//			gfx.lineStyle(1, 0x00FF00);
//			for(var i:int = 0; i < cells.length; i++){
//				gfx.drawRect(cells[i].x * hashMap.scale, cells[i].y * hashMap.scale, hashMap.scale, hashMap.scale);
//			}
//			gfx.drawRect(cell.x * hashMap.scale, cell.y * hashMap.scale, hashMap.scale * 2, hashMap.scale * 2);
//			gfx.lineTo(cell.x * hashMap.scale, cell.y * hashMap.scale);
		}
	}
}
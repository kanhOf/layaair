package laya.d3.resource.tempelet {
	import laya.d3.core.render.IRender;
	import laya.d3.core.render.RenderState;
	import laya.d3.graphics.IndexBuffer3D;
	import laya.d3.graphics.VertexBuffer3D;
	import laya.d3.graphics.VertexParticle;
	import laya.d3.math.Vector2;
	import laya.d3.math.Vector3;
	import laya.d3.shader.ShaderDefines3D;
	import laya.particle.ParticleSettings;
	import laya.particle.ParticleTemplateWebGL;
	import laya.resource.Texture;
	import laya.utils.Handler;
	import laya.utils.Stat;
	import laya.webgl.WebGL;
	import laya.webgl.WebGLContext;
	import laya.webgl.resource.WebGLImage;
	import laya.webgl.shader.Shader;
	import laya.webgl.utils.Buffer;
	import laya.webgl.utils.ValusArray;
	
	/**
	 * @private
	 * <code>ParticleTemplet3D</code> 类用于创建3D粒子数据模板。
	 */
	public class ParticleTemplet3D extends ParticleTemplateWebGL implements IRender {
		private var _vertexBuffer3D:VertexBuffer3D;
		private var _indexBuffer3D:IndexBuffer3D;
		
		protected var _shaderValue:ValusArray = new ValusArray();
		protected var _sharderNameID:int;
		protected var _shader:Shader;
		
		
		
		public function get indexOfHost():int {
			return 0;
		}
		
		public function get VertexBufferCount():int {
			return 1;
		}
		
		public function getBakedVertexs(index:int = 0):Float32Array {
			return null;
		}
		
		public function getBakedIndices():* {
			return null;
		}
		
		public function getVertexBuffer(index:int = 0):VertexBuffer3D {
			if (index === 0)
				return _vertexBuffer3D;
			else
				return null;
		}
		
		public function getIndexBuffer():IndexBuffer3D {
			return _indexBuffer3D;
		}
		
		public function ParticleTemplet3D(parSetting:ParticleSettings) {
			super(parSetting);
			
			initialize();
			loadShaderParams();
			_vertexBuffer = _vertexBuffer3D = VertexBuffer3D.create(VertexParticle.vertexDeclaration,parSetting.maxPartices*4, WebGLContext.DYNAMIC_DRAW);
			_indexBuffer = _indexBuffer3D = IndexBuffer3D.create(parSetting.maxPartices*6,WebGLContext.STATIC_DRAW);
			loadContent();
		}
		
		protected function loadShaderParams():void {
			_sharderNameID = Shader.nameKey.get("PARTICLE");
			
			if (settings.textureName)//预设纹理ShaderValue
			{
				texture = new Texture();
				_shaderValue.pushValue(Buffer.DIFFUSETEXTURE, null, -1);
				var _this:ParticleTemplet3D = this;
				Laya.loader.load(settings.textureName, Handler.create(null, function(texture:Texture):void {
					(texture.bitmap as WebGLImage).enableMerageInAtlas = false;
					(texture.bitmap as WebGLImage).mipmap = true;
					_this.texture = texture;
				}));
			}
			
			_shaderValue.pushValue(Buffer.DURATION, settings.duration, -1);
			_shaderValue.pushValue(Buffer.GRAVITY, settings.gravity, -1);
			_shaderValue.pushValue(Buffer.ENDVELOCITY, settings.endVelocity, -1);
		}
		
		public function addParticle(position:Vector3, velocity:Vector3):void {
			addParticleArray(position.elements, velocity.elements);
		}
		
		public function _render(state:RenderState):Boolean {
			if (texture && texture.loaded) {
				//设备丢失时.............................................................
				//  todo  setData  here!
				//...................................................................................
				if (_firstNewElement != _firstFreeElement) {
					addNewParticlesToVertexBuffer();
				}
				
				if (_firstActiveElement != _firstFreeElement) {
					var gl:WebGLContext = WebGL.mainContext;
					_vertexBuffer3D.bind(_indexBuffer3D);
					
					_shader = getShader(state);
					
					var presz:int = _shaderValue.length;
					
					_shaderValue.pushArray(state.shaderValue);
					_shaderValue.pushArray(_vertexBuffer3D.vertexDeclaration.shaderValues);
					
					_shaderValue.pushValue(Buffer.MVPMATRIX, state.owner.transform.getWorldMatrix(2).elements, -1);
					_shaderValue.pushValue(Buffer.MATRIX1, state.viewMatrix.elements, -1);
					_shaderValue.pushValue(Buffer.MATRIX2, state.projectionMatrix.elements, -1);
					
					//设置视口尺寸，被用于转换粒子尺寸到屏幕空间的尺寸
					var aspectRadio:Number = state.viewport.width / state.viewport.height;
					var viewportScale:Vector2 = new Vector2(0.5 / aspectRadio, -0.5);
					_shaderValue.pushValue(Buffer.VIEWPORTSCALE, viewportScale.elements, -1);
					
					//设置粒子的时间参数，可通过此参数停止粒子动画
					_shaderValue.pushValue(Buffer.CURRENTTIME, _currentTime, -1);
					
					_shaderValue.data[1][0] = texture.source;//可能为空
					_shaderValue.data[1][1] = texture.bitmap.id;
					
					_shader.uploadArray(_shaderValue.data, _shaderValue.length, null);
					
					_shaderValue.length = presz;
					
					var drawVertexCount:int;
					if (_firstActiveElement < _firstFreeElement) {
						drawVertexCount = (_firstFreeElement - _firstActiveElement) * 6;
						WebGL.mainContext.drawElements(WebGLContext.TRIANGLES, drawVertexCount, WebGLContext.UNSIGNED_SHORT, _firstActiveElement * 6 * 2);//2为ushort字节数
						Stat.trianglesFaces += drawVertexCount / 3;
						Stat.drawCall++;
					} else {
						drawVertexCount = (settings.maxPartices - _firstActiveElement) * 6;
						WebGL.mainContext.drawElements(WebGLContext.TRIANGLES, (settings.maxPartices - _firstActiveElement) * 6, WebGLContext.UNSIGNED_SHORT, _firstActiveElement * 6 * 2);//2为ushort字节数
						Stat.trianglesFaces += drawVertexCount / 3;
						Stat.drawCall++;
						if (_firstFreeElement > 0) {
							drawVertexCount = _firstFreeElement * 6;
							WebGL.mainContext.drawElements(WebGLContext.TRIANGLES, _firstFreeElement * 6, WebGLContext.UNSIGNED_SHORT, 0);
							Stat.trianglesFaces += drawVertexCount / 3;
							Stat.drawCall++;
						}
					}
					
				}
				_drawCounter++;
				return true;
			}
			return false;
		}
		
		protected function getShader(state:RenderState):Shader {
			var shaderDefs:ShaderDefines3D = state.shaderDefs;
			var preDef:int = shaderDefs._value;
			//_disableDefine && (shaderDefs._value = preDef & (~_disableDefine));
			shaderDefs.addInt(ShaderDefines3D.PARTICLE3D);
			var nameID:Number = (shaderDefs._value | state.shadingMode) + _sharderNameID * Shader.SHADERNAME2ID;
			_shader = Shader.withCompile(_sharderNameID, state.shadingMode, shaderDefs.toNameDic(), nameID, null);
			shaderDefs._value = preDef;
			return _shader;
		}
	}
}
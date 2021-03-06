package laya.d3.core.render {
	import laya.d3.graphics.IndexBuffer3D;
	import laya.d3.graphics.VertexBuffer3D;
	import laya.webgl.utils.VertexBuffer2D;
	
	/**
	 * <code>IRender</code> 接口用于实现3D对象的渲染相关功能。
	 */
	public interface IRender {
		function get indexOfHost():int
		
		function get VertexBufferCount():int;
		
		function getBakedVertexs(index:int = 0):Float32Array;
		function getBakedIndices():*;
		
		function getVertexBuffer(index:int = 0):VertexBuffer3D;
		function getIndexBuffer():IndexBuffer3D;
		function _render(state:RenderState):Boolean;
	}
}
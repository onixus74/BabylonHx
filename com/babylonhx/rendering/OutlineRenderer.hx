package com.babylonhx.rendering;

import com.babylonhx.materials.Effect;
import com.babylonhx.mesh.SubMesh;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.mesh._InstancesBatch;
import com.babylonhx.materials.Material;
import com.babylonhx.math.Matrix;
import com.babylonhx.math.Tools as MathTools;

/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.OutlineRenderer') class OutlineRenderer {
	
	private var _scene:Scene;
	private var _effect:Effect;
	private var _cachedDefines:String;
	
	public var zOffset:Float = 1;
	

	public function new(scene:Scene) {
		this._scene = scene;
	}

	public function render(subMesh:SubMesh, batch:_InstancesBatch, useOverlay:Bool = false) {
		var scene = this._scene;
		var engine = this._scene.getEngine();
		
		var hardwareInstancedRendering = (engine.getCaps().instancedArrays) && (batch.visibleInstances[subMesh._id] != null);
		
		if (!this.isReady(subMesh, hardwareInstancedRendering)) {
			return;
		}
		
		var mesh = subMesh.getRenderingMesh();
		var material = subMesh.getMaterial();
		
		engine.enableEffect(this._effect);
		
		// Logarithmic depth
        if (Reflect.field(material, "useLogarithmicDepth") == true) {
            this._effect.setFloat("logarithmicDepthConstant", 2.0 / (Math.log(scene.activeCamera.maxZ + 1.0) / MathTools.LN2));
        }
		
		this._effect.setFloat("offset", useOverlay ? 0 : mesh.outlineWidth);
		this._effect.setColor4("color", useOverlay ? mesh.overlayColor : mesh.outlineColor, useOverlay ? mesh.overlayAlpha : 1.0);
		this._effect.setMatrix("viewProjection", scene.getTransformMatrix());
		
		// Bones
		if (mesh.useBones && mesh.computeBonesUsingShaders) {
			this._effect.setMatrices("mBones", mesh.skeleton.getTransformMatrices(mesh));
		}
		
		mesh._bind(subMesh, this._effect, Material.TriangleFillMode);
		
		// Alpha test
		if (material != null && material.needAlphaTesting()) {
			var alphaTexture = material.getAlphaTestTexture();
			
			if (alphaTexture != null) {
				this._effect.setTexture("diffuseSampler", alphaTexture);
				this._effect.setMatrix("diffuseMatrix", alphaTexture.getTextureMatrix());
			}
		}
		
		engine.setZOffset(-this.zOffset);
		
		mesh._processRendering(subMesh, this._effect, Material.TriangleFillMode, batch, hardwareInstancedRendering, function(_, world:Matrix, _) { 
			this._effect.setMatrix("world", world);
		});
		
		engine.setZOffset(0);
	}

	public function isReady(subMesh:SubMesh, useInstances:Bool):Bool {
		var defines:Array<String> = [];
		var attribs = [VertexBuffer.PositionKind, VertexBuffer.NormalKind];
		
		var mesh = subMesh.getMesh();
		var material = subMesh.getMaterial();
		
		if (material != null) {
			// Alpha test
			if (material.needAlphaTesting()) {
				defines.push("#define ALPHATEST");
				if (mesh.isVerticesDataPresent(VertexBuffer.UVKind)) {
					attribs.push(VertexBuffer.UVKind);
					defines.push("#define UV1");
				}
				if (mesh.isVerticesDataPresent(VertexBuffer.UV2Kind)) {
					attribs.push(VertexBuffer.UV2Kind);
					defines.push("#define UV2");
				}
			}
			//Logarithmic depth
			if (Reflect.field(material, "useLogarithmicDepth") == true) {
				defines.push("#define LOGARITHMICDEPTH");
			}
		}
		
		// Bones
		if (mesh.useBones && mesh.computeBonesUsingShaders) {
			attribs.push(VertexBuffer.MatricesIndicesKind);
			attribs.push(VertexBuffer.MatricesWeightsKind);
			if (mesh.numBoneInfluencers > 4) {
                attribs.push(VertexBuffer.MatricesIndicesExtraKind);
                attribs.push(VertexBuffer.MatricesWeightsExtraKind);
            }
            defines.push("#define NUM_BONE_INFLUENCERS " + mesh.numBoneInfluencers);
			defines.push("#define BonesPerMesh " + (mesh.skeleton.bones.length + 1));
		} 
		else {
			defines.push("#define NUM_BONE_INFLUENCERS 0");
		}
		
		// Instances
		if (useInstances) {
			defines.push("#define INSTANCES");
			attribs.push("world0");
			attribs.push("world1");
			attribs.push("world2");
			attribs.push("world3");
		}
		
		// Get correct effect      
		var join = defines.join("\n");
		if (this._cachedDefines != join) {
			this._cachedDefines = join;
			this._effect = this._scene.getEngine().createEffect("outline",
				attribs,
				["world", "mBones", "viewProjection", "diffuseMatrix", "offset", "color", "logarithmicDepthConstant"],
				["diffuseSampler"], join);
		}
		
		return this._effect.isReady();
	}
	
}

![](http://i.imgur.com/JOLB62m.png)

# vvvvery_physical
## A node-based pathtracer on the GPU integrated into [vvvv](https://vvvv.org/)

### Status
It's something around "pre-alpha". Feature-incomplete, but perhaps fun to fool around with and get a taste of what's possible.
At the moment, you can render spheres, boxes, and arbitrary SDFs in basic material setups. Performance varies based on scene content but is 
definitely not optimized much at this point.

### Why
There are many raytracers available today. The distinguishing feature about this one is the emphasis on procedural content.
With vvvv comes support for procedurally defining the objects in your scene. In addition, you gain the flexibility of a big collection of nodes
to define custom pipelines, mix raytracing with rasterized rendering, and more.

### What
This raytracer is a collection of HLSL shaders designed to take input from [vvvv.DX11](https://vvvv.org/contribution/directx11-nodes) buffers.
There are also some convenience patches for outputting the render and defining different primitives, materials, and lights. The rest is up to you.

You can choose to render iteractively (continuously adding samples) or set a desired sample limit. You can also output animations or single images - 
all the abilities of vvvv are at your disposal.

### Dependencies
 * [vvvv](https://vvvv.org/)
 * [vvvv addons](https://vvvv.org/documentation/addons)
 * [vvvv.DX11](https://vvvv.org/contribution/directx11-nodes)

### Features
 - [x] construct your scene graph, material definitions, and lighting through nodes
 - [x] change source shader code on the fly
 - [x] support for primitives and signed-distance field volumes
 - [x] basic diffuse/specular materials
 - [x] textures
 - [ ] photometric light units
 - [ ] HDRI/IBL support
 - [ ] physical sky
 - [ ] polygonal meshes
 - [ ] accelerated through BVH
 - [ ] principled material
 - [ ] volume material
 - [ ] girlpower (tutorial) patches and examples
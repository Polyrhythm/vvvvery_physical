using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using OpenCvSharp;
using SharpDX;

namespace physical
{
    public unsafe class BVH
    {
        public List<BVHNode> _nodes;
        private BoundingBox _worldBounds;
        private uint _threshold;
        private BVHPrimitive[] _primitives;
        private uint _leaves = 0;

        public BVH(IEnumerable<Primitive> primitives, BoundingBox worldBounds, uint threshold)
        {
            _nodes = new List<BVHNode>();
            _worldBounds = worldBounds;
            _threshold = threshold;

            _primitives = new BVHPrimitive[primitives.Count()];
            for (uint i = 0; i < primitives.Count(); i++)
            {
                _primitives.SetValue(new BVHPrimitive(primitives.ElementAt((int)i), i), i);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BVHNode
        {
            public Vector3 MinBounds;
            public Vector3 MaxBounds;
            public int IsLeaf;
            public int LeftIndex;
            public int RightIndex;
            public int SplitAxis;
            public fixed int Leaves[2]; // _threshold + 1

            public BVHNode(BoundingBox aabb, int isLeaf, int leftIndex, int rightIndex)
            {
                MinBounds = aabb.Minimum;
                MaxBounds = aabb.Maximum;
                IsLeaf = isLeaf;
                LeftIndex = leftIndex;
                RightIndex = rightIndex;

                fixed (int* arr = Leaves)
                {
                    for (int i = 0; i < 1; i++)
                    {
                        int* leaf = &arr[i];
                        *leaf = -1;
                    }
                }

                SplitAxis = -1;
            }

            public void SetAABB(BoundingBox aabb)
            {
                MinBounds = aabb.Minimum;
                MaxBounds = aabb.Maximum;
            }
        }

        private struct BVHPrimitive
        {
            public Primitive Primitive;
            public uint OriginalIndex;

            public BVHPrimitive(Primitive primitive, uint originalIndex)
            {
                Primitive = primitive;
                OriginalIndex = originalIndex;
            }
        }

        private void BuildRecursive(int nodeIdx, int leftIdx, int rightIdx, int depth)
        {
            var node = _nodes[nodeIdx];
            if (rightIdx - leftIdx <= _threshold)
            {
                // assign node as leaf node
                node.IsLeaf = 1;

                for (int i = 0; i <= rightIdx - leftIdx; i++)
                {
                    node.Leaves[i] = (int) _primitives[leftIdx + i].OriginalIndex;
                    _leaves++;
                }

                _nodes[nodeIdx] = node;
                return;
            }

            // find largest dimension of current BVH node
            Vector3 midpoint = Vector3.Lerp(node.MinBounds, node.MaxBounds, 0.5f);
            Vector3 diff = node.MaxBounds - node.MinBounds;
            Vector3 maxDir = BVHBuilder.FindMaxDir(diff);

            if (maxDir.X == 1.0f)
            {
                node.SplitAxis = 1;
            }
            else if (maxDir.Y == 1.0f)
            {
                node.SplitAxis = 2;
            }
            else
            {
                node.SplitAxis = 3;
            }

            // sort by largest dimension
            _primitives.Skip(leftIdx).Take(rightIdx - leftIdx + 1)
                .OrderBy(x =>
                {
                    Vector3 mid = Vector3.Lerp(x.Primitive.MinBounds, x.Primitive.MaxBounds, 0.5f);

                    if (maxDir.X > 0)
                    {
                        return mid.X;
                    }
                    else if (maxDir.Y > 0)
                    {
                        return mid.Y;
                    }

                    return mid.Z;
                })
                .ToArray()
                .CopyTo(_primitives, leftIdx);

            // find the midpoint index of intersectables in the current node
            // The midpoint index is inclusive for the lefthand child node
            int midIdx = leftIdx;

            if (rightIdx - leftIdx <= _threshold * 2)
            {
                midIdx = leftIdx + (int)_threshold;
            }

            // If there are only three intersectables left, force the split in the middle
            else if (rightIdx - leftIdx == 2)
            {
                midIdx++;
            }

            // If there's only two intersectables left, force the split regardless of where the midpoint is
            else if (rightIdx - leftIdx != 1)
            {
                for (; midIdx < rightIdx - 1; midIdx++)
                {
                    BVHPrimitive sortedPrim = _primitives[midIdx];
                    Vector3 mid = Vector3.Lerp(sortedPrim.Primitive.MinBounds, sortedPrim.Primitive.MaxBounds, 0.5f) * maxDir;
                    Vector3 nodeMid = midpoint * maxDir;

                    // Check to see if the current intersectable is to the right of the current BVH node midpoint
                    if (mid.X > nodeMid.X || mid.Y > nodeMid.Y || mid.Z > nodeMid.Z)
                    {
                        break;
                    }
                }
            }

            BoundingBox leftBox;
            BoundingBox rightBox;
            if (rightIdx - leftIdx == 1)
            {
                Primitive leftPrim = _primitives[leftIdx].Primitive;
                Primitive rightPrim = _primitives[rightIdx].Primitive;
                leftBox = new BoundingBox(leftPrim.MinBounds, leftPrim.MaxBounds);
                rightBox = new BoundingBox(rightPrim.MinBounds, rightPrim.MaxBounds);
            }
            else
            {
                // Create left side bounding box
                Primitive leftPrim = _primitives[leftIdx].Primitive;
                leftBox = new BoundingBox(leftPrim.MinBounds, leftPrim.MaxBounds);
                for (int x = leftIdx + 1; x <= midIdx; x++)
                {
                    leftPrim = _primitives[x].Primitive;
                    leftBox = BoundingBox.Merge(leftBox, new BoundingBox(leftPrim.MinBounds, leftPrim.MaxBounds));
                }

                // Create right side bounding box
                Primitive rightPrim = _primitives[midIdx + 1].Primitive;
                rightBox = new BoundingBox(rightPrim.MinBounds, rightPrim.MaxBounds);
                for (int y = midIdx + 2; y <= rightIdx; y++)
                {
                    rightPrim = _primitives[y].Primitive;
                    rightBox = BoundingBox.Merge(rightBox, new BoundingBox(rightPrim.MinBounds, rightPrim.MaxBounds));
                }

            }
            
            
            // Create left and right nodes, assign them bounds, recursively build their trees
            BVHNode leftNode = new BVHNode(new BoundingBox(), 0, -1, -1);
            BVHNode rightNode = new BVHNode(new BoundingBox(), 0, -1, -1);

            leftNode.SetAABB(leftBox);
            rightNode.SetAABB(rightBox);

            // Set indices on current node to point to children
            node.LeftIndex = _nodes.Count();
            node.RightIndex = _nodes.Count() + 1;
            _nodes[nodeIdx] = node;

            _nodes.Add(leftNode);
            _nodes.Add(rightNode);

            BuildRecursive(node.LeftIndex, leftIdx, midIdx, depth + 1); // left child
            BuildRecursive(node.RightIndex, midIdx + 1, rightIdx, depth + 1); // right child
        }

        public void BuildBVH()
        {
            if (!_primitives.Any() || _worldBounds.Minimum == Vector3.Zero && _worldBounds.Maximum == Vector3.Zero)
            {
                return;
            }

            BVHNode root = new BVHNode(new BoundingBox(), 0, -1, -1);
            root.SetAABB(_worldBounds);
            _nodes.Add(root);

            int left = 0;
            int right = _primitives.Count() - 1;

            // recursively build the BVH
            BuildRecursive(0, left, right, 0);
        }
    }

    public static class BVHBuilder
    {
        // Calculate world bounds from a list of primitives.
        public static BoundingBox CalculateWorldBounds(IEnumerable<Primitive> primitives)
        {
            BoundingBox WorldAABB = new BoundingBox(Vector3.Zero, Vector3.Zero);

            if (!primitives.Any())
            {
                return WorldAABB;
            }

            foreach (var primitive in primitives)
            {
                WorldAABB = BoundingBox.Merge(WorldAABB, new BoundingBox(primitive.MinBounds, primitive.MaxBounds));
            }

            return WorldAABB;
        }

        public static Vector3 FindMaxDir(Vector3 vec)
        {
            float max = vec.ToArray().Max();

            if (max == vec.X) return Vector3.UnitX;
            else if (max == vec.Y) return Vector3.UnitY;
            else return Vector3.UnitZ;
        }

        public static IEnumerable<BVH.BVHNode> CreateBVH(BoundingBox worldBounds, IEnumerable<Primitive> primitives, bool enable=false)
        {
            if (!enable)
            {
                return new BVH.BVHNode[0];
            }

            uint THRESHOLD = 1;
            BVH bvh = new BVH(primitives, worldBounds, THRESHOLD);
            bvh.BuildBVH();
            return bvh._nodes;
        }

        public static IEnumerable<Matrix> GetBVHTransforms(IEnumerable<BVH.BVHNode> nodes, bool enable=false)
        {
            if (!enable)
            {
                return new Matrix[0];
            }

            List<Matrix> matrices = new List<Matrix>();

            foreach (var node in nodes)
            {
                Matrix transform = Matrix.Identity;
                Vector3 size = node.MaxBounds - node.MinBounds;
                transform.ScaleVector = size;

                Vector3 pos = Vector3.Lerp(node.MinBounds, node.MaxBounds, 0.5f);
                transform.TranslationVector = pos;

                matrices.Add(transform);
            }

            return matrices;
        }
    }
}


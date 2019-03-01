using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;
using SharpDX;

namespace physical
{
    public class BVH
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct BVHNode
        {
            public BoundingBox AABB;
            public int ChildA;
            public int ChilbB;

            public BVHNode(BoundingBox aabb, int childA, int childB)
            {
                AABB = aabb;
                ChildA = childA;
                ChilbB = childB;
            }
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
                BoundingBox.Merge(WorldAABB, primitive.AABB);
            }

            return WorldAABB;
        }

        public static IEnumerable<BVH.BVHNode> BuildBVH(IEnumerable<Primitive> primitives, BoundingBox WorldBounds)
        {
            if (!primitives.Any() || WorldBounds.Minimum == Vector3.Zero && WorldBounds.Maximum == Vector3.Zero)
            {
                return new List<BVH.BVHNode>();
            }
        }
    }
}

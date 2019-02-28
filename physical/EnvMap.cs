﻿using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using OpenCvSharp;
using SharpDX;

namespace physical
{
    public static class EnvMap
    {
        public static void BuildDistributions(OpenCvSharp.Mat envMap, out Mat marginalDistTexture, out Mat conditionalDistTexture, bool enabled = false)
        {
            marginalDistTexture = new Mat();
            conditionalDistTexture = new Mat();

            if (!enabled)
            {
                return;
            }

            int width = envMap.Width;
            int height = envMap.Height;
            int[] sizes = {width, height};

            Point2f[] marginalData = new Point2f[height];
            Point2f[] conditionalData = new Point2f[width * height];

            float[] pdf2d = new float[width * height];
            float[] cdf2d = new float[width * height];
            float[] pdf1d = new float[height];
            float[] cdf1d = new float[height];

            float colWeightSum = 0.0f;

            for (int y = 0; y < height; y++)
            {
                float rowWeightSum = 0.0f;

                for (int x = 0; x < width; x++)
                {
                    Vec3f colour = envMap.At<Vec3f>(x, y);
                    float weight = getLuminance(colour);
                    rowWeightSum += weight;

                    pdf2d[y * width + x] = weight;
                    cdf2d[y * width + x] = rowWeightSum;
                }

                for (int x = 0; x < width; x++)
                {
                    pdf2d[y * width + x] /= rowWeightSum;
                    cdf2d[y * width + x] /= rowWeightSum;
                }

                colWeightSum += rowWeightSum;
                pdf1d[y] = rowWeightSum;
                cdf1d[y] = colWeightSum;
            }

            for (int y = 0; y < height; y++)
            {
                cdf1d[y] /= colWeightSum;
                pdf1d[y] /= colWeightSum;
            }

            // pre-calculate row and col to avoid a binary search in the shader
            for (int i = 0; i < height; i++)
            {
                float invHeight = (float)i / height;
                int row = LowerBound(ref cdf1d, 0, height, invHeight);
                Point2f result = new Point2f(row / (float)height, pdf1d[i]);
                marginalData[i] = result;
            }

            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    float invWidth = (float) x / width;
                    int col = LowerBound(ref cdf2d, y * width, (y + 1) * width, invWidth) - y * width;
                    Point2f result = new Point2f(col / (float)width, pdf2d[y * width + x]);
                    conditionalData[y * width + x] = result;
                }
            }

            // set the output vars
            marginalDistTexture = new Mat(height, 1, MatType.CV_32FC2, marginalData);
            conditionalDistTexture = new Mat(width, height, MatType.CV_32FC2, conditionalData);
        }

        private static float getLuminance(Vec3f colour)
        {
            return 0.299f * colour[0] + 0.587f * colour[1] + 0.114f * colour[2];
        }

        private static int LowerBound(ref float[] array, int lower, int upper, float value)
        {
            while (lower < upper)
            {
                int mid = lower + (upper - lower) / 2;
                if (array[mid] < value)
                {
                    lower = mid + 1;
                }
                else
                {
                    upper = mid;
                }
            }

            return lower;
        }
    }
}

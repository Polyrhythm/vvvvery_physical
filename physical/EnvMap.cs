﻿using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Dynamic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using OpenCvSharp;
using OpenCvSharp.Extensions;
using SharpDX;

namespace physical
{
    public static class EnvMap
    {
        public static void BuildDistributions(Mat envMap, string outDir = "", bool enabled = false)
        {
            if (!enabled)
            {
                return;
            }

            int width = envMap.Width;
            int height = envMap.Height;
            int[] marginalSize = {height, 1};
            int[] conditionalSize = {height, width};

            Vector3[] marginalData = new Vector3[height];
            Vector3[] conditionalData = new Vector3[width * height];

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
                    Vec3f colour = envMap.At<Vec3f>(y, x);
                    float weight = getLuminance(colour);
                    rowWeightSum += weight;

                    pdf2d[x * height + y] = weight;
                    cdf2d[x * height + y] = rowWeightSum;
                }

                for (int x = 0; x < width; x++)
                {
                    pdf2d[x * height + y] /= rowWeightSum;
                    cdf2d[x * height + y] /= rowWeightSum;
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
                Vector3 result = new Vector3(row / (float)height, pdf1d[i], 0.0f);
                marginalData[i] = result;
            }

            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    float invWidth = (float) x / width;
                    int col = LowerBound(ref cdf2d, y * width, (y + 1) * width, invWidth) - y * width;
                    Vector3 result = new Vector3(col / (float)width, pdf2d[y * width + x], 0.0f);
                    conditionalData[y * width + x] = result;
                }
            }

            // set the output vars
            Mat marginalMat = new Mat(marginalSize, MatType.CV_16UC3, marginalData);
            Mat conditionalMat = new Mat(conditionalSize, MatType.CV_16UC3, conditionalData);

            marginalMat.SaveImage(outDir + "marginal.png");
            conditionalMat.SaveImage(outDir + "conditional.png");
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

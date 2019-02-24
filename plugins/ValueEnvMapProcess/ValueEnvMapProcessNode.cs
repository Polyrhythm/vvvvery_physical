#region usings
using System;
using System.ComponentModel.Composition;
using System.IO;

using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;
using VVVV.Utils.VColor;
using VVVV.Utils.VMath;

using VVVV.Core.Logging;

using SlimDX.Direct3D11;
using SlimDX;

using VVVV.DX11;

using FeralTic.DX11;
using FeralTic.DX11.Resources;

#endregion usings

namespace VVVV.Nodes
{
	#region PluginInfo
	[PluginInfo(Name = "EnvMapProcess", Category = "DX11.Texture")]
	#endregion PluginInfo
	
	public class EnvMapProcessNode : IPluginEvaluate, IDX11ResourceHost, IDisposable
	{
		#region fields & pins
		[Input("HDR Data", AutoValidate = false)]
		protected Pin<Stream> hdrDataIn;
		
		[Input("Apply", IsBang = true, DefaultValue = 1)]
		public ISpread<bool> apply;
		
		[Input("Width", DefaultValue = 1, AutoValidate = false)]
		protected ISpread<int> inWidth;
		
		[Input("Height", DefaultValue = 1, AutoValidate = false)]
		protected ISpread<int> inHeight;

		[Output("MarginalTexture")]
		protected Pin<DX11Resource<DX11Texture2D>> marginalTexture;
		
		[Output("Valid")]
		protected ISpread<bool> isValid;
		
		[Import()]
		protected IPluginHost host;

		[Import()]
		public ILogger FLogger;
		
		private float[] marginalData = new float[0];
		private float[] conditionalData = new float[0];
		
		private Spread<byte> byteSpread = new Spread<Byte>(1);
		
		private bool invalidate = true;
		
		#endregion fields & pins
		

		//called when data for any output pin is requested
		public void Evaluate(int SpreadMax)
		{
			if (!this.apply[0])
			{
				return;
			}
			
			this.inWidth.Sync();
			this.inHeight.Sync();
			this.hdrDataIn.Sync();
			this.invalidate = true;
			
			if (SpreadMax == 0)
			{
				if (this.marginalTexture.SliceCount == 1)
				{
					this.marginalTexture.SafeDisposeAll();
				}
			}
			else
			{
				this.marginalTexture.SliceCount = 1;
				if (this.marginalTexture[0] == null)
				{
					this.marginalTexture[0] = new DX11Resource<DX11Texture2D>();
				}
			}
			
			
			
		}
		
		public unsafe void Update(DX11RenderContext context)
		{
			FLogger.Log(LogType.Debug, "1");
			if (!this.invalidate)
			{
				return;
			}
			FLogger.Log(LogType.Debug, "2");
			
			
			FLogger.Log(LogType.Debug, "3");
			
			if (this.marginalTexture[0].Contains(context))
			{
				FLogger.Log(LogType.Debug, "dispose");
				this.marginalTexture[0].Dispose(context);
			}
			
			var data = this.hdrDataIn[0];
			if (this.hdrDataIn.IsConnected && data != null)
			{
				FLogger.Log(LogType.Debug, "yep");
				SlimDX.DXGI.Format fmt = SlimDX.DXGI.Format.R32G32B32A32_Float;
				int pixelSize = 16;
				
				int stride = 128;
				FLogger.Log(LogType.Debug, "4");
				FLogger.Log(LogType.Debug, data.Length.ToString());
				byteSpread.SliceCount = stride * pixelSize * this.inHeight[0];
				FLogger.Log(LogType.Debug, "5");
				
				data.Read(byteSpread.Stream.Buffer, 0, stride * this.inHeight[0]);
				FLogger.Log(LogType.Debug, "6");
				data.Position = 0;
				
				using (SlimDX.DataStream dataStream = new DataStream(byteSpread.Stream.Buffer,
					true, true))
				{
					DX11Texture2D texture = DX11Texture2D.CreateImmutable(context,
						this.inWidth[0], this.inHeight[0], fmt, stride, dataStream);
					
					this.marginalTexture[0][context] = texture;
				}
			}
			
			this.invalidate = false;
			
		}
		
		public void Destroy(DX11RenderContext context, bool force)
		{
			this.marginalTexture[0].Dispose(context);
		}
		
		#region IDisposable Members
		public void Dispose()
		{
			if (this.marginalTexture.SliceCount > 0)
			{
				if (this.marginalTexture[0] != null)
				{
					this.marginalTexture[0].Dispose();
				}
			}
		}
		#endregion
	}
}

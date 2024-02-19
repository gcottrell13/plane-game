using Godot;
using System;

[Tool, GlobalClass]
public partial class ParallaxSprite2D : Sprite2D
{
	public ParallaxSprite2D()
	{
		TextureRepeat = TextureRepeatEnum.Enabled;
		RegionEnabled = true;
	}

	[Export]
	public Vector2 ScrollSpeed { get; set; }
	private Vector2 _textureSize;

	public override void _Ready()
	{
		TextureChanged += OnTextureChanged;
		_textureSize = Texture?.GetSize() ?? new();
	}

	public override void _PhysicsProcess(double delta)
	{
		FollowCamera();
	}

	private void FollowCamera()
	{
		if (Engine.IsEditorHint())
			return;

		Viewport viewport = GetViewport();
		Camera2D camera = viewport.GetCamera2D();
		Vector2 position = camera.GetScreenCenterPosition();

		if (camera.AnchorMode == Camera2D.AnchorModeEnum.DragCenter)
		{
			position -= viewport.GetVisibleRect().Size * 0.5f;
		}

		Offset = position / Scale;

		Vector2 scroll = (position * ScrollSpeed / Scale % _textureSize).Round();
		RegionRect = new(scroll, RegionRect.Size);
	}

	private void OnTextureChanged()
	{
		_textureSize = Texture.GetSize();
		RegionRect = new(RegionRect.Position, _textureSize);
	}
}

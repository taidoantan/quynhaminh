using PdfSharp.Fonts;

namespace QuyNhaMinh.Api.Services;

public sealed class QnmFontResolver(string contentRoot) : IFontResolver {
    private readonly string root = Path.Combine(contentRoot, "Assets", "Fonts");
    public byte[] GetFont(string faceName) => File.ReadAllBytes(Path.Combine(root, faceName == "NotoBold" ? "NotoSans-Bold.ttf" : "NotoSans-Regular.ttf"));
    public FontResolverInfo ResolveTypeface(string familyName, bool isBold, bool isItalic) => new(isBold ? "NotoBold" : "NotoRegular");
}

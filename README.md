![FuchidoriPopToon](https://github.com/JohnTonarino/FuchidoriPopToon/assets/141009460/8e0fa71a-c77d-4643-918e-aa466b171e2b)
# 概要
VRChatでの使用を想定したアウトラインにこだわりのあるシェーダーです。

オブジェクトの内側と外側とで異なるアウトラインを描画できます。

ライティングにはOpenLitを使用しています。

https://github.com/lilxyzw/OpenLit

2024/05/05 1.0.0 リリース

2024/05/06 1.0.1 OutlineMaskが有効になっていなかった不具合を修正。Outlineだけに対してLightの影響度を調整できるパラメータAsOutlineUnlitを追加。

2024/05/11 1.0.2 リファクタリング。特定のPostProcessing影響下でStencilの値を原因として透過する現象が確認されたため、透過しないStencil値を初期値として設定。

2024/05/28 1.0.3 Shadowに関する不具合の修正。SDFFaceShadowに対応。

2024/08/14 1.0.4 2影の実装。

2024/12/27 1.0.5 鏡面反射まわりの修正。影の境界を柔らかくできるように。

# 利用規約
MITライセンスで公開しています。
https://docs.google.com/document/d/1OkF35q4dHSGHCqt23miYk3yhpgeCFMfmQTHPol4tbb8/edit?usp=sharing


# 免責事項
当シェーダーを利用することで発生したトラブルや不利益、損害については、製作者は一切責任を負いかねます。

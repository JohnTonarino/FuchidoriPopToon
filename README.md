![FuchidoriPopToonThumb_107](https://github.com/user-attachments/assets/d4e1db99-3f45-4c28-baf5-e3c12c7294bf)

# 概要
VRChatでの使用を想定したアウトラインにこだわりのあるシェーダーです。

オブジェクトの内側と外側とで異なるアウトラインを描画できます。

Thanks to:
* OpenLit : https://github.com/lilxyzw/OpenLit
* VRCLightVolumes : https://github.com/REDSIM/VRCLightVolumes

# 利用規約
MITライセンスで公開しています。
https://docs.google.com/document/d/1OkF35q4dHSGHCqt23miYk3yhpgeCFMfmQTHPol4tbb8/edit?usp=sharing

# 更新履歴

2024/05/05 1.0.0 リリース

2024/05/06 1.0.1 OutlineMaskが有効になっていなかった不具合を修正。Outlineだけに対してLightの影響度を調整できるパラメータAsOutlineUnlitを追加。

2024/05/11 1.0.2 リファクタリング。特定のPostProcessing影響下でStencilの値を原因として透過する現象が確認されたため、透過しないStencil値を初期値として設定。

2024/05/28 1.0.3 Shadowに関する不具合の修正。SDFFaceShadowに対応。

2024/08/14 1.0.4 2影の実装。

2024/12/27 1.0.5 鏡面反射まわりの修正。影の境界を柔らかくできるように。

2025/03/28 1.0.6 リファクタリング。共通の実装をまとめた。

2025/05/24 1.0.7 VRCLightVolumesに対応。ライティング周りの処理の見直し。

# 免責事項
当シェーダーを利用することで発生したトラブルや不利益、損害については、製作者は一切責任を負いかねます。

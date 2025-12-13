import cv2
import dlib
import numpy as np

# 顔検出器の読み込み
detector = dlib.get_frontal_face_detector()

# ニューラルネットワークオブジェクト生成
net = cv2.dnn.readNetFromCaffe(r'deploy.prototxt', r'res10_300x300_ssd_iter_140000_fp16.caffemodel')

# 名前と画像ファイルの対応リスト
names = {
    'person1': r'C:\FaceDetect\img\person2.png',
    'monkey': r'C:\FaceDetect\img\monkey.png',
    'RockSystem': r'C:\FaceDetect\img\RockSystem.png',
}

# 画像ファイルを顔画像として読み込む
face_images = {name: cv2.imread(path) for name, path in names.items()}

# カメラキャプチャの開始
cap = cv2.VideoCapture(0)

while True:
    # フレームの読み込み
    ret, img = cap.read()

    # 顔検出
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = detector(gray)

    
    for face in faces:
        # 顔領域に四角形を描画
        x, y, w, h = face.left(), face.top(), face.width(), face.height()
        cv2.rectangle(img, (x, y), (x + w, y + h), (255, 0, 0), 2)

        # 顔領域を切り取り
        face_roi = img[y:y+h, x:x+w]

        # face_roi が空でないか確認
        if face_roi is None or face_roi.size == 0:
            print("顔領域が空です")
            continue  # スキップして次の顔を処理

        # 顔認識の処理...
        blob = cv2.dnn.blobFromImage(face_roi, 1.0, (300, 300), (104.0, 177.0, 123.0))
        net.setInput(blob)
        detections = net.forward()

        # 顔認識結果の取得
        confidence = detections[0, 0, 0, 2]
        if confidence > 0.5:
            # 最大類似度
            max_similarity = 0.0
            max_name = 'Unknown'
            # 最も類似度が高い名前を取得
            for name, face_image in face_images.items():
                similarity = cv2.compareHist(cv2.calcHist([face_roi], [0], None, [256], [0, 256]),
                                             cv2.calcHist([face_image], [0], None, [256], [0, 256]),
                                             cv2.HISTCMP_CORREL)
                # 類似度が更新された場合、一致する氏名を更新
                if similarity > max_similarity:
                    max_similarity = similarity
                    max_name = name

            # 顔領域に名前を表示
            cv2.putText(img, max_name, (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 0, 0), 2)

    # 画像の表示
    cv2.imshow('video image', img)

    #　キー入力待機
    key = cv2.waitKey(10)

    # ESCキーでループ終了
    if key == 27:
        break

# カメラキャプチャの停止
cap.release()

# ウィンドウの破棄
cv2.destroyAllWindows()
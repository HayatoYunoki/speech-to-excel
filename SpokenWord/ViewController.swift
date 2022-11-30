import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDataSource, UIPickerViewDelegate {
    
    // MARK: Properties
    // 音声認識系統の変数定義
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var recordButton: UIButton!
    
    @IBOutlet weak var tytleTable: UITableView!
    
    @IBOutlet weak var contentTable: UITableView!
    
    @IBOutlet weak var pageSettingPicker: UIPickerView!
    
    @IBOutlet weak var savedLabel: UILabel!
    
    // その他変数定義
    //タイトル(左側の列)の配列
    var tytleArray: NSMutableArray = [""]
    //右側の列の配列
    var contentArray: NSMutableArray = [""]
    var items: [NSMutableArray] = []
    var contentIndex: Int = 0
    var startDate = Date().addingTimeInterval(-180071.3325)
    var nextCount: Int = 0
    var place = 0
    //確定されたセルのインデックスは1になる
    var isDec = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    //呼ばれたセルのインデックスが格納される集合
    var calledIndex: Set<Int> = []
    var page = 1
    var csvArray: [String]!
    var csvLength:Int = 0
    //選択されたセルのインデックスは1になる
    var isSelect =  [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    //セル幅を大きくするセルを保存する(現状では"内容"のとき)
    var largeCell: Set<Int> = []
    //picker用
    var pageNumber: String?
    let settingKey = "timer_value"
    let settingArray: [String] = ["page1", "page2", "page3"]
    
    // tableViewの表示用 tag=0は左列 tag=1は右列
    var tag:Int = 0
    var cellIdentifier:String = ""
    
    // MARK: View Controller Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let settings = UserDefaults.standard
        settings.register(defaults: [settingKey:"page1"])
        pageSettingPicker.delegate = self
        pageSettingPicker.dataSource = self
        let pageValue = settings.string(forKey: settingKey)
        
        //Pickerの選択を合わせる
        for row in 0..<settingArray.count{
            if settingArray[row] == pageValue{
                pageSettingPicker.selectRow(row, inComponent: 0, animated: true)
            }
        }
        
        // 表示用データの配列を配列にする
            items.append(tytleArray)
            items.append(contentArray)
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        readCSVFile()
        tytleTable.allowsMultipleSelection = true
        
        //空のセルを非表示
        tytleTable.tableFooterView = UIView()
        contentTable.tableFooterView = UIView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }
    
    // tableViewの内容表示準備
        func checkTableView(_ tableView: UITableView) -> Void{
            if (tableView.tag == 0) {
                tag = 0
                cellIdentifier = "tytleCell"
            }
            else if (tableView.tag == 1) {
                tag = 1
                cellIdentifier = "contentCell"
            }
        }
    
        // MARK: - テーブルビュー
        // セルの数を返す。
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            checkTableView(tableView)

            return items[tag].count
        }

        // セルを返す。
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            checkTableView(tableView)

            // セルにテキストを出力する。
            let cell = tableView.dequeueReusableCell(withIdentifier:  cellIdentifier, for:indexPath as IndexPath)
            cell.textLabel?.text = items[tag][indexPath.row] as? String
            if tag == 1 && self.isDec[indexPath.row] == 1{
                cell.textLabel?.textColor = #colorLiteral(red: 1, green: 0.1491314173, blue: 0, alpha: 1)
            }
            else if tag == 1 && self.isDec[indexPath.row] == 0{
                cell.textLabel?.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            }
        
            if tag == 0 && calledIndex.contains(indexPath.row){
                cell.textLabel?.textColor = #colorLiteral(red: 1, green: 0.1491314173, blue: 0, alpha: 1)
            }
            else if tag == 0 && !calledIndex.contains(indexPath.row){
                cell.textLabel?.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            }
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            
        if largeCell.contains(indexPath.row){
            //改行を可能にする
            cell.textLabel?.numberOfLines = 0
        }
            return cell
        }
    
    //セルの高さを変更する
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if largeCell.contains(indexPath.row){
            return 400.0
        }
        else{
            return 40.0
        }
    }

    // テーブルビューをスワイプしてデータを削除する。
    public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            let deleteButton: UITableViewRowAction = UITableViewRowAction(style: .normal, title: "削除") { (action, index) -> Void in
                self.checkTableView(tableView)
                self.items[self.tag].removeObject(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
            deleteButton.backgroundColor = UIColor.red

            return [deleteButton]
        }
    
    //選択(数値入力セル用)
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let cell = tableView.cellForRow(at: indexPath)
            
            // タップされたセルの行番号を出力
        if tableView == tytleTable{
            cell?.accessoryType = .checkmark
            print("\(indexPath.row)番目の行が選択されました。")
            isSelect[indexPath.row] = 1
        }
    }
    //選択解除
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
            let cell = tableView.cellForRow(at:indexPath)
            
            // タップされたセルの行番号を出力
        if tableView == tytleTable{
            cell?.accessoryType = .none
            print("\(indexPath.row)番目の行が解除されました。")
            isSelect[indexPath.row] = 0
        }
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        //文字列処理のアルゴリズムは別途フローチャート参照
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                
                isFinal = result.isFinal
                
                for tytle in self.tytleArray{
                    if result.bestTranscription.formattedString.hasSuffix(tytle as! String + "消去") {
                        self.isDec[self.tytleArray.index(of: tytle)] = 0
                        self.contentArray[self.tytleArray.index(of: tytle)] = ""
                    }
                    else if result.bestTranscription.formattedString.contains(tytle as! String){
                        
                        let index = self.tytleArray.index(of: tytle)
                        
                        var displayArray = result.bestTranscription.formattedString.components(separatedBy: tytle as! String)
                        self.calledIndex.insert(index)
                        
                        if self.isDec[index] == 0{
                            displayArray[displayArray.count-1] = displayArray[displayArray.count-1].replacingOccurrences(of:"消去",with:"")
                            self.contentArray[index] = displayArray[displayArray.count-1].replacingOccurrences(of:"確定",with:"")
                            //数値のみのセルの判定
                            let predicate = NSPredicate(format: "SELF MATCHES '\\\\d+'")
                            if self.isSelect[index] == 1 && !predicate.evaluate(with: self.contentArray[index] as! String) && self.contentArray[index] as! String != ""{
                                self.contentArray[index] = "Only Number"
                            }
                        }
                    
                        if result.bestTranscription.formattedString.hasSuffix("確定"){
                            self.isDec[index] = 1
                        }
                        //break
                    }
                    self.contentTable.reloadData()
                    self.tytleTable.reloadData()
                }
                
                if result.bestTranscription.formattedString.hasSuffix("保存"){
                    self.createCSVFile()
                }
                
                if result.bestTranscription.formattedString.hasSuffix("終了"){
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                    self.recordButtonTapped()
                    guard let task = self.recognitionTask else {
                                fatalError("Error")
                            }
                            task.cancel()
                            task.finish()
               }
                print("Text \(result.bestTranscription.formattedString)")
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle("Stop Recording", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
    //saveボタンがタップされたとき
    @IBAction func saveButtonTApped(_ sender: Any) {
        createCSVFile()
    }
    
    func createCSVFile(){
        var text:String = ""
        for singleString in contentArray{
            text += singleString as! String + ","
        }
        let csvName: String
        if page == 1 {
            csvName = "data1.csv"
        }
        else if page == 2 {
            csvName = "data2.csv"
        }
        else {
            csvName = "data3.csv"
        }
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            let path = dir.appendingPathComponent(csvName)

            do {
                try (text as AnyObject).write(to: path, atomically: true, encoding: String.Encoding.utf8.rawValue)
                savedLabel.text = "csv saved"
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.savedLabel.text = ""
                }
            } catch let error as NSError {
                print("エラー：\(error)")
            }
        }
    }
    
    //enterボタンがタップされたとき
    @IBAction func decisionButtonTapped(_ sender: Any) {
        largeCell = []
        readCSVFile()
        for i in 0..<tytleTable.numberOfRows(inSection: 0) {
            let indexPath = IndexPath(row: i, section: 0)
            let cell = tytleTable.cellForRow(at: indexPath)
            cell?.accessoryType = .none
            tytleTable.deselectRow(at: indexPath, animated: true)
            if isSelect[i] == 1{
                isSelect[i] = 0
            }
            //print(isSelect)
        }
    }
    
    func readCSVFile(){
        //MARK: csvファイルの読み込み
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
               do {
                var fileURL = documentPath.appendingPathComponent("test3.csv")
                if page == 1{
                    fileURL = documentPath.appendingPathComponent("test1.csv")
                }
                else if page == 2{
                    fileURL = documentPath.appendingPathComponent("test2.csv")
                }
                let csvData = try String(contentsOf: fileURL)
                csvArray = csvData.components(separatedBy: ",")
                csvLength = csvArray.count
                tytleArray.removeAllObjects()
                contentArray.removeAllObjects()
                //print(csvLength)
                for i in 0...csvLength-1{
                    contentArray[i] = ""
                }
                for i in 0...csvLength-1{
                    tytleArray[i] = csvArray[i]
                    isDec[i] = 0
                }
                //tytleArrayの最後のセルから\nを取り除く
                var dropN: String = tytleArray[csvLength-1] as! String
                dropN = String(dropN.dropLast())
                tytleArray[csvLength-1] = dropN
                
                //タイトルが内容であるセルを調べる
                for i in 0...csvLength-1{
                    if tytleArray[i] as! String == "内容"{
                        largeCell.insert(i)
                    }
                }
                
                calledIndex.removeAll()
                contentTable.reloadData()
                tytleTable.reloadData()
               } catch{
                    print("読み込み失敗")
                    savedLabel.text = "Read failure"
               }
    }
    
    // MARK: UIPickerView
    
    //UIPickerViewの列数を設定
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    //UIPickerViewの行数を取得
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        return settingArray.count
    }
    
    //UIPickerViewの表示する内容を設定
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(settingArray[row])
    }
    
    //picker選択時に実行
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int){
        let settings = UserDefaults.standard
        settings.setValue(settingArray[row], forKey: settingKey)
        settings.synchronize()
        page = row + 1
    }
    
    
    @IBAction func resetButtonTapped(_ sender: Any) {
        // ボタンを押下した時にアラートを表示するメソッド
            // UIAlertControllerクラスのインスタンスを生成
            // タイトル, メッセージ, Alertのスタイルを指定する
            // 第3引数のpreferredStyleでアラートの表示スタイルを指定する
        let alert: UIAlertController = UIAlertController(title: "リセット", message: "リセットしてもいいですか？", preferredStyle:  UIAlertController.Style.alert)

            // Actionの設定
            // Action初期化時にタイトル, スタイル, 押された時に実行されるハンドラを指定する
            // 第3引数のUIAlertActionStyleでボタンのスタイルを指定する
            // OKボタン
        let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:{
                // ボタンが押された時の処理を書く（クロージャ実装）
                (action: UIAlertAction!) -> Void in
                self.readCSVFile()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recordButtonTapped()
                guard let task = self.recognitionTask else {
                        fatalError("Error")
                }
                task.cancel()
                task.finish()
            
            })
            // キャンセルボタン
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler:{
        
                // ボタンが押された時の処理を書く（クロージャ実装）
                (action: UIAlertAction!) -> Void in
                print("Cancel")
            })

            // UIAlertControllerにActionを追加
            alert.addAction(cancelAction)
            alert.addAction(defaultAction)

            // Alertを表示
        present(alert, animated: true, completion: nil)
    }
    
}

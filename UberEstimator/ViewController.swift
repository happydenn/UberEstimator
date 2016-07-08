//
//  ViewController.swift
//  UberEstimator
//
//  Created by Denny Tsai on 7/8/16.
//  Copyright © 2016 hpd.io. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    
    @IBOutlet weak var originTextField: UITextField!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var surgeSlider: UISlider!
    @IBOutlet weak var surgeRateLabel: UILabel!
    
    @IBOutlet weak var startPriceLabel: UILabel!
    @IBOutlet weak var distancePriceLabel: UILabel!
    @IBOutlet weak var timePriceLabel: UILabel!
    @IBOutlet weak var distanceSurchargePriceLabel: UILabel!
    @IBOutlet weak var normalFareLabel: UILabel!
    @IBOutlet weak var surgeFareLabel: UILabel!
    @IBOutlet weak var totalFareLabel: UILabel!
    
    @IBOutlet weak var calculateButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var currentLocationButton: UIButton!
    
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceSurchargeLabel: UILabel!
    @IBOutlet weak var surgeLabel: UILabel!
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var resultView: UIView!
    @IBOutlet weak var surgeView: UIView!
    
    let minFare = 50.0
    let startPrice = 30.0
    let perMinutePrice = 2.0
    let perKMPrice = 11.5
    let distanceSurchargeKM = 15.0
    let distanceSurchargePerKMPrice = 11.5
    
    var completedQueries = 0
    var locations = [String: MKMapItem]()
    var surgeRate = 1.0
    var distance = 0.0
    var travelTime = 0.0
    
    let locationManager = CLLocationManager()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 將一些View在View Controller一開始時隱藏
        loadingView.hidden = true
        resultView.hidden = true
        surgeView.hidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // 畫面出現後將輸入框框放到起點
        originTextField.becomeFirstResponder()
    }
    
    @IBAction func getCurrentLocationTapped(sender: AnyObject) {
        // 詢問使用者地理位置存取權限
        // 需在Info.plist檔案新增一個NSLocationWhenInUseUsageDescription的key，寫入需要使用地理位置資訊的說明
        locationManager.requestWhenInUseAuthorization()

        // 將起點設定為目前位置的MapItem
        locations["origin"] = MKMapItem.mapItemForCurrentLocation()
        originTextField.text = "現在位置"
        
        // 將輸入位置移到目的地
        destinationTextField.becomeFirstResponder()
    }
    
    @IBAction func calculateTapped(sender: AnyObject) {
        // 把鍵盤收起來
        view.endEditing(true)
        
        // 開始計算，將完成數及字典內容歸零
        completedQueries = 0
        
        // 開始讀取狀態
        changeLoadingStatus(true)
        
        // 搜尋輸入的地點位置
        queryOriginAndDestinationLocations()
        
        // 將結果和加成slider隱藏
        resultView.hidden = true
        surgeView.hidden = true
    }
    
    @IBAction func resetTapped(sender: AnyObject) {
        // 將計算結果和加乘倍率設定回預設
        distance = 0
        travelTime = 0
        surgeRate = 1
        
        // 清空起點和目的地TextField
        originTextField.text = ""
        destinationTextField.text = ""
        
        // 重設slider和slider label
        surgeRateLabel.text = "1.0x"
        surgeSlider.value = 1
        
        // 將結果和加成slider隱藏
        resultView.hidden = true
        surgeView.hidden = true
        
        // 把輸入設定到起點的框框
        originTextField.becomeFirstResponder()
    }
    
    @IBAction func surgeSliderChanged(sender: AnyObject) {
        // 因為只要取得小數第一位，所以先 x10 四捨五入取整數後再除以10
        surgeRate = Double(round(surgeSlider.value * 10) / 10)
        
        // 更新倍率顯示
        surgeRateLabel.text = String(format: "%.1fx", surgeRate)
        
        // 更新結果
        displayResult()
    }
    
    // 查詢起點和目的地的地點
    func queryOriginAndDestinationLocations() {
        // 讀取originTextField 和 destinationTextField
        if let origin = originTextField.text, destination = destinationTextField.text {
            
            // 如果兩個Text Field的值都不是空字串
            if origin != "" && destination != "" {
                
                // 檢查起點是不是為現在位置
                // 先檢查locations的"origin"這個key是不是已經存在有MKMapItem物件
                if let originLocation = locations["origin"] {
                    // 如果locations的"origin"這個key已經有MKMapItem而且是目前位置時，表示使用者使用現在位置
                    if origin == "現在位置" && originLocation.isCurrentLocation {
                        // 使用現在位置的話就把完成的查詢直接 +1
                        completedQueries += 1
                    } else {
                        // 使用者點了現在位置鈕之後又自行輸入起點，因此需要重新搜尋起點
                        queryLocationCoordinate(origin, type: "origin")
                    }
                    
                } else {
                    // locations的"origin"這個key不存在
                    queryLocationCoordinate(origin, type: "origin")
                }
                
                queryLocationCoordinate(destination, type: "destination")
                
            } else {
                // 起點或目的地為空字串
                print("請完整輸入起點和目的地")
                changeLoadingStatus(false)
                showErrorAlertMessage("請完整輸入起點和目的地")
            }
            
        } else {
            // 起點或目的地輸入錯誤
            print("起點或目的地輸入錯誤")
            changeLoadingStatus(false)
            showErrorAlertMessage("起點或目的地輸入錯誤")
        }
    }
    
    // 使用MKLocalSearch搜尋地點
    func queryLocationCoordinate(query: String, type: String) {
        // 建立MKCoordinateRegion來縮小搜尋範圍
        let center = CLLocationCoordinate2DMake(25.0691801198, 121.53350830075)
        let span = MKCoordinateSpanMake(0.493835104, 0.9722900391)
        let region = MKCoordinateRegion(center: center, span: span)
        
        // 建立MKLocalSearchRequest物件
        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = query
        request.region = region
        
        // 建立MKLocalSearch物件
        let search = MKLocalSearch(request: request)
        
        // 執行搜尋
        search.startWithCompletionHandler { response, error in
            if let error = error {
                print("error: \(error)")
                self.changeLoadingStatus(false)
                self.showErrorAlertMessage("搜尋地點失敗\n(\(error.localizedDescription))")
                return
            }
            
            if let response = response, mapItem = response.mapItems.first {
                // 將地點加入結果字典
                self.locations[type] = mapItem
                
                // 增加完成數
                self.completedQueries += 1
                
                // 檢查目前查詢狀態
                self.checkCompletedQueries()
            } else {
                print("not found")
                self.changeLoadingStatus(false)
                self.showErrorAlertMessage("搜尋地點失敗")
            }
        }
    }
    
    // 檢查是否完成兩個地點的搜尋
    func checkCompletedQueries() {
        if completedQueries == 2 {
            getDirectionForLocations()
        }
    }
    
    // 使用MKDirections查詢兩地的距離和旅行時間
    func getDirectionForLocations() {
        // 建立一個MKDirectionsRequest
        let request = MKDirectionsRequest()
        request.source = locations["origin"]
        request.destination = locations["destination"]
        // 因為Uber是開車，所以指定transportType
        request.transportType = MKDirectionsTransportType.Automobile
        
        // 建立MKDirections
        let directions = MKDirections(request: request)
        
        // 計算距離和旅行時間
        directions.calculateDirectionsWithCompletionHandler { response, error in
            if let error = error {
                print("error: \(error)")
                self.changeLoadingStatus(false)
                self.showErrorAlertMessage("計算行程失敗\n(\(error.localizedDescription))")
                return
            }
            
            if let response = response {
                // 取得結果中的第一條路徑
                let route = response.routes.first!
                
                // 取得路徑的距離和旅行時間並存到View Controller的屬性中
                // 將距離單位轉成公里
                self.distance = route.distance / 1000
                // 將時間單位轉成分鐘
                self.travelTime = route.expectedTravelTime / 60
                
                // 顯示結果
                self.displayResult()
                
            } else {
                print("no response")
                self.changeLoadingStatus(false)
                self.showErrorAlertMessage("計算行程失敗")
            }
        }
    }
    
    func displayResult() {
        // 計算最終車資
        let distancePrice = distance * perKMPrice
        let travelTimePrice = travelTime * perMinutePrice
        
        // 遠距加成車資
        var surchargeDistance = distance - distanceSurchargeKM
        if surchargeDistance < 0 {
            surchargeDistance = 0
        }
        let distanceSurchargePrice = surchargeDistance * distanceSurchargePerKMPrice
        
        // 一般計價車資
        let normalFare = startPrice + distancePrice + travelTimePrice + distanceSurchargePrice
        // 閃電加成車資，閃電加乘倍率要 - 1，否則會double價錢
        let surgeFare = (surgeRate - 1) * (startPrice + distancePrice + travelTimePrice)
        // 調整最低車資
        let adjustedMinFare = minFare * surgeRate
        
        // 車資合計
        var totalFare = normalFare + surgeFare
        if totalFare < adjustedMinFare {
            totalFare = adjustedMinFare
        }
        
        // 取得搜尋結果的地點名稱
        let locationNames = getLocationNames()
        
        // 將搜尋結果的地名放回起點和目的地的TextField
        originTextField.text = locationNames.origin
        destinationTextField.text = locationNames.destination
        
        // 其他資訊顯示
        distanceLabel.text = String(format: "%.2f 公里", distance)
        timeLabel.text = String(format: "%.2f 分鐘", travelTime)
        distanceSurchargeLabel.text = String(format: "遠距加收 (%.2f 公里)", surchargeDistance)
        
        startPriceLabel.text = String(format: "%.2f", startPrice)
        distancePriceLabel.text = String(format: "%.2f", distancePrice)
        timePriceLabel.text = String(format: "%.2f", travelTimePrice)
        distanceSurchargePriceLabel.text = String(format: "%.2f", distanceSurchargePrice)
        
        surgeLabel.text = String(format: "閃電加成 (%.1fx)", surgeRate)
        normalFareLabel.text = String(format: "%.2f", normalFare)
        surgeFareLabel.text = String(format: "%.2f", surgeFare)
        
        totalFareLabel.text = String(format: "%.2f", totalFare)
        
        // 切換讀取狀態
        changeLoadingStatus(false)
        
        // 將結果和加成slider顯示
        resultView.hidden = false
        surgeView.hidden = false
    }
    
    // 取得兩個地點的地名
    // 其實這段可以用下面這一行完成
    func getLocationNames() -> (origin: String, destination: String) {
        // 先確認locations字典裡面有"origin"跟"destination"這兩個key
        if let origin = locations["origin"], destination = locations["destination"] {
            var originName: String
            
            if origin.isCurrentLocation {
                // 起點如果是現在地點就回傳現在地點
                originName = "現在位置"
            } else {
                originName = origin.name!
            }
            
            // 回傳起點和目的地的地點名稱
            return (originName, destination.name!)
        }
        
        // 預設回傳兩個空字串
        return ("", "")
    }
    
    // 切換讀取狀態
    func changeLoadingStatus(loading: Bool) {
        print("loading status: \(loading)")
        
        // 啟用/停用按鈕
        calculateButton.enabled = !loading
        resetButton.enabled = !loading
        currentLocationButton.enabled = !loading
        
        // 讀取進度
        loadingView.hidden = !loading
        
        // 螢幕左上角的小讀取菊花
        UIApplication.sharedApplication().networkActivityIndicatorVisible = loading
    }
    
    // 顯示錯誤dialog
    func showErrorAlertMessage(message: String) {
        // 建立錯誤dialog controller
        let alertController = UIAlertController(title: "錯誤", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        // 建立 OK 按鈕
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { action in
            // 按鈕按下時，將目前顯示的alert移除
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        
        // 將OK按鈕加入alertController
        alertController.addAction(okAction)
        
        // 顯示alert
        presentViewController(alertController, animated: true, completion: nil)
    }
    
}

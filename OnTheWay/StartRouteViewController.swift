// Copyright 2016 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

enum SuggestionType {
    case POI
    case PopulatedPlace
}

class StartRouteViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    @IBOutlet var tableView:UITableView!
    @IBOutlet var preferredSearchLocationTextField:UITextField!
    @IBOutlet var poiTextField:UITextField!
    @IBOutlet var tableViewHeightConstraint:NSLayoutConstraint!
    @IBOutlet var getDirectionsButton:UIButton!
    @IBOutlet var routeInProgressIndicator:UIActivityIndicatorView!
    @IBOutlet var mapViewContainer:UIView!
    
    private var textFieldLocationButton:UIButton!
    
    private var suggestResults:[AGSSuggestResult]!
    private var suggestRequestOperation:AGSCancelable!
    private var selectedSuggestResult:AGSSuggestResult!
    private var preferredSearchLocation:AGSPoint!
    private var selectedTextField:UITextField!
    
    private var isTableViewVisible = true
    private var isTableViewAnimating = false
    
    private var currentLocationText = "Current Location"
    private var isUsingCurrentLocation = false
    private let tableViewHeight:CGFloat = 120
    
    private var startLocation:AGSPoint!
    private var endLocation:AGSPoint!
    
    private let mapView = AGSMapView(frame: CGRect.zero)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //hide suggest result table view by default
        self.animateTableView(expand: false)
        
        //add the left view images for both the textfields
        self.setupTextFieldLeftViews()
        
        mapView.frame = mapViewContainer.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapViewContainer.addSubview(mapView)
        
        mapView.map = AGSMap.redlandsMap()
        
        let point1 = AGSPoint(x: -117.23176575926132, y: 34.066904648027112, spatialReference: AGSSpatialReference.wgs84())
        let point2 = AGSPoint(x: -117.23176675926132, y: 34.066914648027112, spatialReference: AGSSpatialReference.wgs84())
        let point3 = AGSPoint(x: -117.23176775926132, y: 34.066924648027112, spatialReference: AGSSpatialReference.wgs84())
        let point4 = AGSPoint(x: -117.23176875926132, y: 34.066934648027112, spatialReference: AGSSpatialReference.wgs84())
        let point5 = AGSPoint(x: -117.23176975926132, y: 34.066944648027112, spatialReference: AGSSpatialReference.wgs84())
        let point6 = AGSPoint(x: -117.23176875926132, y: 34.066934648027112, spatialReference: AGSSpatialReference.wgs84())
        let point7 = AGSPoint(x: -117.23176775926132, y: 34.066924648027112, spatialReference: AGSSpatialReference.wgs84())
        let point8 = AGSPoint(x: -117.23176675926132, y: 34.066914648027112, spatialReference: AGSSpatialReference.wgs84())
        
        let polyline = AGSPolyline.init(points: [point1, point2, point3, point4, point5, point6, point7, point8])
        
        let ds = AGSSimulatedLocationDataSource()
        ds.setLocationsWith(polyline)
        
        mapView.locationDisplay.dataSource = ds
        mapView.locationDisplay.start(completion: nil)
        mapView.locationDisplay.autoPanMode = .recenter
        
        self.title = "Drift"
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: nil, action: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //method to show search icon and pin icon for the textfields
    private func setupTextFieldLeftViews() {
        var leftView = self.textFieldViewWithImage(imageName: "SearchIcon")
        self.poiTextField.leftView = leftView
        self.poiTextField.leftViewMode = UITextFieldViewMode.always
        
        leftView = self.textFieldViewWithImage(imageName: "PinIcon")
        self.preferredSearchLocationTextField.leftView = leftView
        self.preferredSearchLocationTextField.leftViewMode = UITextFieldViewMode.always
        self.preferredSearchLocationTextField.text = currentLocationText
    }
    
    //method returns a UIView with an imageView as the subview
    //with an image instantiated using the name provided
    private func textFieldViewWithImage(imageName:String) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 25, height: 30))
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.frame = CGRect(x: 5, y: 5, width: 20, height: 20)
        view.addSubview(imageView)
        return view
    }
    
    //method to toggle the suggestions table view on and off
    private func animateTableView(expand:Bool) {
        if (expand != self.isTableViewVisible) && !self.isTableViewAnimating {
            self.isTableViewAnimating = true
            self.tableViewHeightConstraint.constant = expand ? self.tableViewHeight : 0
            UIView.animate(withDuration: 0.1, animations: { [weak self] () -> Void in
                self?.view.layoutIfNeeded()
                }, completion: { [weak self] (finished) -> Void in
                    self?.isTableViewAnimating = false
                    self?.isTableViewVisible = expand
                })
        }
    }
    
    //method to clear prefered location information
    //hide the suggestions table view, empty previously selected
    //suggest result and previously fetch search location
    private func clearPreferredLocationInfo() {
        self.animateTableView(expand: false)
        self.selectedSuggestResult = nil
        self.preferredSearchLocation = nil
    }
    
    //MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows = 0
        if let count = self.suggestResults?.count {
            if self.selectedTextField == self.preferredSearchLocationTextField {
                rows = count + 1
            }
            else {
                rows = count
            }
        }
        self.animateTableView(expand: rows > 0)
        return rows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestCell")!
        let isLocationTextField = (self.selectedTextField == self.preferredSearchLocationTextField)
        
        if isLocationTextField && indexPath.row == 0 {
            cell.textLabel?.text = self.currentLocationText
            cell.imageView?.image = UIImage(named: "CurrentLocationDisabledIcon")
            return cell
        }
        
        let rowNumber = isLocationTextField ? indexPath.row - 1 : indexPath.row
        let suggestResult = self.suggestResults[rowNumber]
        
        cell.textLabel?.text = suggestResult.label
        cell.imageView?.image = nil
        return cell
    }
    
    //MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if self.selectedTextField == self.preferredSearchLocationTextField {
            if indexPath.row == 0 {
                self.preferredSearchLocationTextField.text = self.currentLocationText
            }
            else {
                let suggestResult = self.suggestResults[indexPath.row - 1]
                self.selectedSuggestResult = suggestResult
                self.preferredSearchLocation = nil
                self.selectedTextField.text = suggestResult.label
            }
        }
        else {
            let suggestResult = self.suggestResults[indexPath.row]
            self.selectedTextField.text = suggestResult.label
        }
        self.animateTableView(expand: false)
    }
    
    //MARK: - UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        
        if !(self.preferredSearchLocationTextField.text?.isEmpty)! && !(self.poiTextField.text?.isEmpty)! {
            self.getDirectionsButton.isEnabled = true;
        }
        else {
            self.getDirectionsButton.isEnabled = false;
        }
        
        if textField == self.preferredSearchLocationTextField {
            self.selectedTextField = self.preferredSearchLocationTextField
            if !newString.isEmpty {
                self.fetchSuggestions(string: newString, suggestionType: .PopulatedPlace, textField: self.preferredSearchLocationTextField)
            }
            self.clearPreferredLocationInfo()
        }
        else {
            self.selectedTextField = self.poiTextField
            if !newString.isEmpty {
                self.fetchSuggestions(string: newString, suggestionType: .POI, textField:self.poiTextField)
            }
            else {
                self.animateTableView(expand: false)
            }
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == self.preferredSearchLocationTextField {
            self.clearPreferredLocationInfo()
        }
        else {
            self.animateTableView(expand: false)
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.animateTableView(expand: false)
        if (self.poiTextField.text?.isEmpty)! || (self.preferredSearchLocationTextField.text?.isEmpty)! {
            self.getDirectionsButton.isEnabled = false
        }
    }
    
    //MARK: - Suggestions logic
    
    private func fetchSuggestions(string:String, suggestionType:SuggestionType, textField:UITextField) {
        //cancel previous requests
        if self.suggestRequestOperation != nil {
            self.suggestRequestOperation.cancel()
        }
        
        //initialize suggest parameters
        let suggestParameters = AGSSuggestParameters()
        let flag:Bool = (suggestionType == SuggestionType.POI)
        suggestParameters.categories = flag ? ["POI"] : ["Populated Place"]
        //TODO:mt - suggestParameters.preferredSearchLocation = flag ? nil : self.mapView.locationDisplay.mapLocation
        
        //get suggestions
        let appContext = AppContext.shared
        self.suggestRequestOperation = appContext.locatorTask.suggest(withSearchText: string, parameters: suggestParameters) { (result: [AGSSuggestResult]?, error: Error?) -> Void in
            if string == textField.text { //check if the search string has not changed in the meanwhile
                if let error = error {
                    print(error.localizedDescription)
                }
                else {
                    //update the suggest results and reload the table
                    self.suggestResults = result
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    private func geocodeUsingSuggestResult(suggestResult:AGSSuggestResult, completion: @escaping () -> Void) {
        
        //create geocode params
        let params = AGSGeocodeParameters()
        params.outputSpatialReference = AGSSpatialReference.wgs84()
        
        //geocode with selected suggest result
        AppContext.shared.locatorTask.geocode(with: suggestResult, parameters: params) { [weak self] (result: [AGSGeocodeResult]?, error: Error?) -> Void in
            if let error = error {
                print(error.localizedDescription)
            }
            else {
                if let result = result , result.count > 0 {
                    self?.preferredSearchLocation = result[0].displayLocation
                    completion()
                }
                else {
                    print("No location found for the suggest result")
                }
            }
        }
    }
    
    private func geocodePOIs(poi:String, location:AGSPoint?, extent:AGSGeometry?) {
        //parameters for geocoding POIs
        let params = AGSGeocodeParameters()
        params.preferredSearchLocation = location
        params.searchArea = extent
        params.outputSpatialReference = AGSSpatialReference.wgs84()
        params.resultAttributeNames.append(contentsOf: ["*"])
        
        
        //geocode using the search text and params
        let appContext = AppContext.shared
        appContext.locatorTask.geocode(withSearchText: poi, parameters: params, completion: { [weak self] (results:[AGSGeocodeResult]?, error:Error?) -> Void in
            if let error = error {
                print(error.localizedDescription)
            }
            else {
                self?.handleGeocodeResultsForPOIs(geocodeResults: results, areExtentBased: (extent != nil))
            }
            })
    }
    
    private func handleGeocodeResultsForPOIs(geocodeResults:[AGSGeocodeResult]?, areExtentBased:Bool) {
        if let results = geocodeResults , results.count > 0 {
            
            self.startLocation = AGSPoint(x: -117.23176575926132, y: 34.066904648027112, spatialReference: AGSSpatialReference.wgs84())
            self.endLocation = results[0].displayLocation!
            
            calculateRoute(point1: self.startLocation, point2: self.endLocation){ [weak self] routeResult, error in
                if let error = error{
                    self?.routeInProgressIndicator.isHidden = true
                    // TODO: let's show an error
                    let alert = UIAlertController(title: "Error Calculating Route", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(alert, animated: true, completion: nil)
                }
                else if let routeResult = routeResult{
                    self?.routeInProgressIndicator.isHidden = true
                    let mapVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MapViewController") as! MapViewController
                    mapVC.routeResult = routeResult
                    self?.navigationController?.pushViewController(mapVC, animated: true)
                }
            }
            
        }
        else {
            //show alert for no results
            self.routeInProgressIndicator.isHidden = true
            print("No results found")
            let alert = UIAlertController(title: "Error Calculating Route", message: "No results found", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    //MARK: - Actions
    
    private func search() {
        //validation
        guard let poi = self.poiTextField.text , !poi.isEmpty else {
            self.routeInProgressIndicator.isHidden = true
            print("Point of interest required")
            let alert = UIAlertController(title: "Error Calculating Route", message: "Point of interest required", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        //cancel previous requests
        if self.suggestRequestOperation != nil {
            self.suggestRequestOperation.cancel()
        }
        
        //hide the table view
        self.animateTableView(expand: false)
        
        //check if a suggestion is present
        if self.selectedSuggestResult != nil {
            //since a suggestion is selected, check if it was already geocoded to a location
            //if no, then goecode the suggestion
            //else use the geocoded location, to find the POIs
            if self.preferredSearchLocation == nil {
                self.geocodeUsingSuggestResult(suggestResult: self.selectedSuggestResult, completion: { [weak self] () -> Void in
                    //find the POIs wrt location
                    self?.geocodePOIs(poi: poi, location: self!.preferredSearchLocation, extent: nil)
                    })
            }
            else {
                self.geocodePOIs(poi: poi, location: self.preferredSearchLocation, extent: nil)
            }
        }
        else {
            self.geocodePOIs(poi: poi, location: nil, extent: nil)
        }
    }
    
    //MARK: - Gesture recognizers
    
    @IBAction private func hideKeyboard() {
        self.view.endEditing(true)
    }
    
    @IBAction private func getDirections() {
        self.routeInProgressIndicator.isHidden = false
        self.search()
        
    }
    
    deinit {
    }
}

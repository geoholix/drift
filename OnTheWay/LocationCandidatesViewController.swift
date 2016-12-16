//
//  LocationCandidatesViewController.swift
//  OnTheWay
//
//  Created by Ryan Olson on 12/15/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import UIKit
import ArcGIS

class LocationCandidateCell : UITableViewCell{
    
    @IBOutlet weak var candidateImageView: UIImageView!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    
    var lastRequestOp : AGSRequestOperation?
    
    
    var candidate: LocationCandidate? {
        didSet{
            configure()
        }
    }
    
    override func prepareForReuse() {
        candidateImageView.image = nil
        label1.text = nil
        label2.text = nil
        label3.text = nil
        label4.text = nil
        lastRequestOp?.cancel()
    }
    
    func configure(){
        guard let candidate = candidate else{
            return
        }
        
        if let url = candidate.yelpBusiness.imageURL{
            let reqOp = AGSRequestOperation(url: url)
            reqOp.registerListener(self){ [weak candidate, weak self] result, error in
                
                guard let strongSelf = self, let strongCandidate = candidate else{
                    return
                }
                
                if strongCandidate != strongSelf.candidate{
                    return
                }
                
                guard let data = result as? Data else {
                    return
                }
                
                let image = UIImage(data: data)
                strongSelf.candidateImageView.image = image
                strongSelf.lastRequestOp = nil
            }
            AGSOperationQueue.shared().addOperation(reqOp)
            lastRequestOp = reqOp
        }
        
        // name
        label1.text = candidate.yelpBusiness.name
        
        // address string
        let addressString = candidate.yelpBusiness.location.address.reduce(""){ result, string in
            if result.isEmpty {
                return string
            }
            else{
                return result + ", " + string
            }
        }
        label3.text = addressString
        
        
        // distance from strings
        
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        
        let distance = AGSLinearUnit.meters().convert(candidate.distanceFromRoute, to: AGSLinearUnit.miles())
        let distanceText = "\(nf.string(for: distance)!) miles Off Route"
        
        let distanceFromHere = AGSLinearUnit.meters().convert(candidate.distanceFromStartingLocation, to: AGSLinearUnit.miles())
        let distanceFromHereText = "\(nf.string(for: distanceFromHere)!) miles From Here"
        
        //let scoreText = "score: \(nf.string(for: locationCandidate.score)!)"
        
        label2.text = distanceText + ", " + distanceFromHereText
        
        // rating, number reviews
        var ratingString = ""
        for _ in 0..<Int(candidate.yelpBusiness.rating){
            ratingString += "★"
        }
        for _ in 0..<(5-Int(candidate.yelpBusiness.rating)){
            ratingString += "☆"
        }
        ratingString += " \(candidate.yelpBusiness.reviewCount) Reviews"
        
        label4.text = ratingString
        label4.textColor = UIColor(red:0.97, green:0.51, blue:0.20, alpha:1.00)
        
    }
    
    @IBAction func yelpButtonAction(_ sender: Any) {
        
        guard let candidate = candidate else {
            return
        }
        
        let vc = SFSafariViewController(url: candidate.yelpBusiness.url)
        vc.modalPresentationStyle = .overFullScreen
        UIApplication.shared.topViewController()?.present(vc, animated: true, completion: nil)
    }
}

class LocationCandidatesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var cellReuseIdentifier = "LocationCandidateCell"
    
    var resultContext : ResultContext?{
        didSet{
            locationCandidates = resultContext?.candidates ?? [LocationCandidate]()
        }
    }
    
    private(set) var locationCandidates = [LocationCandidate](){
        didSet{
            self.tableView?.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Choose a Location"
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        let bbi = UIBarButtonItem(title: "Where", style: .plain, target: self, action: #selector(mapAction))
        navigationItem.rightBarButtonItem = bbi
    }

    func mapAction(){
        let vc = YelpProcessMapViewController()
        vc.resultContext = resultContext
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationCandidates.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! LocationCandidateCell
        
        let locationCandidate = locationCandidates[indexPath.row]
        cell.candidate = locationCandidate
        //cell.accessoryType = .disclosureIndicator
    
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        let candidate = locationCandidates[indexPath.row]
        
        let alert = UIAlertController(title: "Confirm Drift", message: "Are you sure you want to Drift to \"\(candidate.yelpBusiness.name)\"?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes!", style: .default, handler: {
            action in
            self.driftTo(candidate)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
    
    }

    func driftTo(_ candidate: LocationCandidate){
        
        guard let begin : AGSPoint = resultContext?.locationDisplay.mapLocation,
            let end : AGSPoint = resultContext?.route.stops.last?.geometry else{
                return
        }
        
        calculateRoute(beginPoint: begin, onTheWayPoint: candidate.mapLocation, endPoint: end){ routeResult, error in
            
            if let error = error{
                let alert = UIAlertController(title: "Error Calculating Route", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            else if let routeResult = routeResult{
                if let mapVC = AppContext.shared.mapViewController {
                    mapVC.routeResult = routeResult
                    let _ = self.navigationController?.popToViewController(mapVC, animated: true)
                }
            }
            
        }
    }
}








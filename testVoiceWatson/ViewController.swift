//
//  ViewController.swift
//  testVoiceWatson
//
//  Created by Chris on 11/10/15.
//  Copyright © 2015 Idea360. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    var soundRecorder: AVAudioRecorder!
    var soundPlayer: AVAudioPlayer!
    let username = "4acb8d94-bd6a-4559-9193-6d4b354300be"
    let password = "KV58PdLri0E1"
    
    @IBOutlet weak var recordOutlet: UIButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var resultTextLabel: UILabel!
    @IBAction func recordTouchDown(sender: AnyObject) {
        self.recordOutlet.backgroundColor = UIColor.redColor()
        recordAudio()
    }
    @IBAction func recordTouchUpInside(sender: AnyObject) {
        self.recordOutlet.backgroundColor = UIColor.clearColor()
        stopRecordAudio()
    }

    @IBAction func playBack(sender: AnyObject) {
        playRecording()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        spinner.hidden = true
        recordOutlet.layer.borderWidth = 1.0
        recordOutlet.layer.masksToBounds = false
        recordOutlet.layer.borderColor = UIColor.blackColor().CGColor
        recordOutlet.layer.cornerRadius = (recordOutlet.frame.size.width / 2)
        recordOutlet.clipsToBounds = true
        
        AVAudioSession.sharedInstance().requestRecordPermission({(granted: Bool)-> Void in
            if granted {
                print("Permission Granted.")
            } else {
                print("Permission to record not granted")
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getDir() -> NSURL {
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
        return NSURL(fileURLWithPath: paths[0])
    }
    
    func getFileURL() -> NSURL {
        return getDir().URLByAppendingPathComponent("recording.wav")
    }
    
    func recordAudio(){
        let settings = [
            AVFormatIDKey: Int(kAudioFileWAVEType),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]
        
        do{
            soundRecorder = try AVAudioRecorder(URL: getFileURL(), settings: settings)
            soundRecorder.delegate = self
            soundRecorder.meteringEnabled = true
            soundRecorder.prepareToRecord()
            soundRecorder.record()
        } catch let error as NSError{
            print(error.localizedDescription)
            stopRecordAudio()
        }
    }
    
    func stopRecordAudio(){
        if soundRecorder != nil {
            soundRecorder.stop()
            callWatson()
        }
    }

    func playRecording(){
        do{
            soundPlayer = try AVAudioPlayer(contentsOfURL: getFileURL())
            soundPlayer.delegate = self
            soundPlayer.play()
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }

    func callWatson(){
        spinner.hidden = false
        spinner.startAnimating()
        resultTextLabel.text = ""
        
        // set up the base64-encoded credentials
        let loginString = NSString(format: "%@:%@", username, password)
        let loginData: NSData = loginString.dataUsingEncoding(NSUTF8StringEncoding)!
        let base64LoginString = loginData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.init(rawValue: 0))

        let url = NSURL(string: "https://stream.watsonplatform.net/speech-to-text/api/v1/recognize")
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/l16;rate=16000", forHTTPHeaderField: "content-type")
        
        request.HTTPBody = NSData(contentsOfURL: getFileURL())
                
        let connection = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) -> Void in
            if let urlData = data {
                do {
                    let response = try NSJSONSerialization.JSONObjectWithData(urlData, options: NSJSONReadingOptions.MutableLeaves) as! NSDictionary
                
                    if let res = response["results"] {
                        let resArr = res as! NSArray
                    
                        if resArr.count > 0 {
                            let firstRes = resArr[0] as! NSDictionary
                            let alts = firstRes["alternatives"] as! NSArray
                            let firstAlt = alts[0] as! NSDictionary
                            let text = firstAlt["transcript"]! as! String
                            let confidence = firstAlt["confidence"] as! Float
                        
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.resultTextLabel.text = text
                                self.spinner.hidden = true
                                self.spinner.stopAnimating()
                            
                                if confidence > 0.6 {
                                    self.resultTextLabel.textColor = UIColor.greenColor()
                                } else {
                                    self.resultTextLabel.textColor = UIColor.redColor()
                                }
                            })
                        } else {
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.resultTextLabel.text = "No results found. Please try again."
                                self.resultTextLabel.textColor = UIColor.redColor()
                                self.spinner.hidden = true
                                self.spinner.stopAnimating()
                            })
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.resultTextLabel.text = "No results found. Please try again."
                            self.resultTextLabel.textColor = UIColor.redColor()
                            self.spinner.hidden = true
                            self.spinner.stopAnimating()
                        })
                    }
                } catch let err as NSError{
                    print(err.localizedDescription)
                }
            } else {
                print(error?.localizedDescription)
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.resultTextLabel.text = error!.localizedDescription
                    self.resultTextLabel.textColor = UIColor.redColor()
                    self.spinner.hidden = true
                    self.spinner.stopAnimating()
                })
            }
        }
        
        connection.resume()
    }
}


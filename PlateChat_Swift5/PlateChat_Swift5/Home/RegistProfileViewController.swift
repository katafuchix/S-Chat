//
//  RegistProfileViewController.swift
//  PlateChat
//
//  Created by cano on 2019/01/04.
//  Copyright © 2019 deskplate. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import NSObject_Rx
import SVProgressHUD
import SDWebImage
import Firebase
import FirebaseFirestore

protocol registProfileVCprotocol {
    func closeOnly()
    func closeRegist()
}

class RegistProfileViewController: UIViewController {

    private let store   = Firestore.firestore()
    private let storage = Storage.storage()

    var delegate: registProfileVCprotocol?

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var profileImageButton: CircleButton!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var manButton: CircleSexButton!
    @IBOutlet weak var womanButton: CircleSexButton!
    @IBOutlet weak var noneButton: CircleSexButton!
    @IBOutlet weak var prefTextField: UITextField!
    @IBOutlet weak var ageTextField: UITextField!

    let viewModel = RegistProfileViewModel()
    var pickerView: UIPickerView = UIPickerView()
    let prefs: Variable<[Int: String]> = Variable([:])
    let prefNameArray: Variable<[String]> = Variable([])
    var agePickerView: UIPickerView = UIPickerView()
    let ages: Variable<[Int: String]> = Variable([:])
    let ageNameArray: Variable<[String]> = Variable([])
    let ageIndexArray: Variable<[Int]> = Variable([])


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.closeButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in
            self?.delegate?.closeOnly()
        }).disposed(by: rx.disposeBag)

        setUserData()
        bind()
    }

    func bind() {
        // ニックネーム
        self.nicknameTextField.rx.text.orEmpty.bind(to: self.viewModel.nickName).disposed(by: rx.disposeBag)

        // 性別
        self.manButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in
            self?.buttonSelect((self?.manButton)!)
        }).disposed(by: rx.disposeBag)

        self.womanButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in
            self?.buttonSelect((self?.womanButton)!)
        }).disposed(by: rx.disposeBag)

        self.noneButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in
            self?.buttonSelect((self?.noneButton)!)
        }).disposed(by: rx.disposeBag)

        // 保存
        saveButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in

            self?.nicknameTextField.resignFirstResponder()
            self?.ageTextField.resignFirstResponder()
            self?.prefTextField.resignFirstResponder()

            if (self?.nicknameTextField.text?.isEmpty)! {
                Alert.init("ニックネームを入力してください")
                    .addAction("OK", completion: { [weak self] _ in
                        self?.nicknameTextField.becomeFirstResponder()
                    })
                    .show(self)
                return
            }

            let age = self?.ageIndexArray.value[(self?.agePickerView.selectedRow(inComponent: 0))!] ?? 0
            let dic = [
                "nickname" : self?.viewModel.nickName.value ?? "",
                "sex" : self?.viewModel.sex.value ?? 0,
                "prefecture_id" : self?.pickerView.selectedRow(inComponent: 0) ?? 0,
                "age" : age,
                "profile_text" : self?.viewModel.profileText.value ?? "",
                ] as [String : Any]
            print(dic)
            SVProgressHUD.show(withStatus: "Updating...")
            UserService.updateLoginUser(dic,completionHandler: { ( user, error) in
                SVProgressHUD.dismiss()
                //guard let user = user else { return }
                if error != nil {
                    self?.showAlert("Error!")
                    return
                } else {
                    self?.dismiss(animated: true, completion: {
                        self?.delegate?.closeRegist()
                    })
                }
            })
        }).disposed(by: rx.disposeBag)

        // 画像
        profileImageButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in
            self?.showUploadActionSheet()
        }).disposed(by: rx.disposeBag)

        // 住所
        self.prefTextField.setInputAccessoryView()
        self.prefTextField.inputView = pickerView
        pickerView.showsSelectionIndicator = true
        self.prefNameArray.value = Constants.prefs.sorted(by: {$0.0 < $1.0}).map { $0.1 }
        pickerView.selectRow(AccountData.prefecture_id, inComponent: 0, animated: false)
        self.prefTextField.text = self.prefNameArray.value[AccountData.prefecture_id]

        self.prefNameArray.asObservable().bind(to: pickerView.rx.itemTitles) {_, item in
            return "\(item)"
            }.disposed(by: rx.disposeBag)

        self.prefTextField.rx.controlEvent(UIControl.Event.editingDidBegin)
            .subscribe(onNext: { [weak self] _ in
                self?.pickerView.selectRow(AccountData.prefecture_id, inComponent: 0, animated: false)
            })
            .disposed(by: rx.disposeBag)

        pickerView.rx.itemSelected.subscribe { [weak self] (event) in
            switch event {
            case .next(let selected):
                self?.prefTextField.text = self?.prefNameArray.value[selected.row]
            default:
                break
            }
            }.disposed(by: rx.disposeBag)

        // 年齢
        self.ageTextField.setInputAccessoryView()
        self.ageTextField.inputView = agePickerView
        agePickerView.showsSelectionIndicator = true
        self.ageNameArray.value = Constants.ages.sorted(by: {$0.0 < $1.0}).map { $0.1 }
        self.ageIndexArray.value = Constants.ages.sorted(by: {$0.0 < $1.0}).map { $0.0 }
        agePickerView.selectRow(AccountData.age, inComponent: 0, animated: false)
        if self.ageNameArray.value.contains("\(AccountData.age)") {
            self.ageTextField.text = "\(AccountData.age)"
        } else {
            self.ageTextField.text = self.ageNameArray.value[AccountData.age]
        }

        self.ageTextField.rx.controlEvent(.editingDidBegin).asDriver()
            .drive(onNext: { [unowned self] _ in
                if self.ageNameArray.value.contains("\(AccountData.age)") {
                    self.agePickerView.selectRow(AccountData.age - 17, inComponent: 0, animated: false)
                }
            })
            .disposed(by: rx.disposeBag)

        self.ageNameArray.asObservable().bind(to: agePickerView.rx.itemTitles) {_, item in
            return "\(item)"
            }.disposed(by: rx.disposeBag)

        agePickerView.rx.itemSelected.subscribe { [weak self] (event) in
            switch event {
            case .next(let selected):
                self?.ageTextField.text = self?.ageNameArray.value[selected.row]
            default:
                break
            }
        }.disposed(by: rx.disposeBag)

    }

    func setUserData() {
        self.nicknameTextField.text = AccountData.nickname
        switch AccountData.sex {
        case 0:
            self.buttonSelect(self.noneButton)
        case 1:
            self.buttonSelect(self.manButton)
        case 2:
            self.buttonSelect(self.womanButton)
        default:
            break
        }
        if let url = AccountData.my_profile_image {
            self.profileImageButton.sd_setBackgroundImage(with: URL(string:url), for: .normal) { [weak self] (image, error, cacheType, url) in
                if error != nil {
                    self?.profileImageButton.setBackgroundImage(UIImage(named: "person-icon"), for: .normal)
                }
            }
        } else {
            self.profileImageButton.setBackgroundImage(UIImage(named: "person-icon"), for: .normal)
        }
    }

    // 性別
    func buttonSelect(_ button: CircleSexButton) {
        if button.isSelected { return }
        self.manButton.isSelected   = false
        self.womanButton.isSelected = false
        self.noneButton.isSelected  = false
        button.isSelected = true
        self.viewModel.sex.value = button.tag
    }

    func uploadImage(_ image: UIImage) {
        SVProgressHUD.show(withStatus: "Uploading...")
        UserService.uploadProfileImage(image, completionHandler: { [weak self] (urlStr, error) in
            SVProgressHUD.dismiss()
            guard let urlStr = urlStr else { return }
            if error != nil {
                self?.showAlert("Error!")
                return
            } else {
                self?.profileImageButton.sd_setBackgroundImage(with: URL(string:urlStr), for: .normal)
                self?.showAlert("プロフィール画像を登録しました")
            }
        })
    }

    func showUploadActionSheet() {
        // styleをActionSheetに設定
        let actionSheet = UIAlertController(title: "プロフィール画像", message: "選択してください。", preferredStyle: UIAlertController.Style.actionSheet)

        // 選択肢を生成
        let cameraAction = UIAlertAction(
            title: "写真を撮る",
            style: .default,
            handler: { [weak self] _ in
                // カメラが利用可能か
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    // 写真を選ぶビュー
                    let pickerView = UIImagePickerController()
                    // 写真の選択元をカメラにする
                    pickerView.sourceType = .camera
                    // トリミング機能ON
                    pickerView.allowsEditing = true
                    // デリゲート
                    pickerView.delegate = self
                    // ビューに表示
                    self?.present(pickerView, animated: true)
                }
        })

        let selectedAlbumAtion = UIAlertAction(
            title: "写真を選択",
            style: .default,
            handler: { [weak self] _ in
                // カメラロールが利用可能か
                if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                    // 写真を選ぶビュー
                    let pickerView = UIImagePickerController()
                    // 写真の選択元をカメラロールにする
                    pickerView.sourceType = .photoLibrary
                    // トリミング機能ON
                    pickerView.allowsEditing = true
                    // デリゲート
                    pickerView.delegate = self
                    // ビューに表示
                    self?.present(pickerView, animated: true)
                }
        })

        let deleteAction = UIAlertAction(
            title: "写真を削除",
            style: .default,
            handler: { [weak self] _ in
                // デフォルト画像に差し替え
                //self?.avatarImageView.image = nil
                //self?.setHiddenAvatarImageView(true)
                //self?.avatarSettings = .removed

                //self?.updateButtons()
        })

        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)

        // アクションを追加
        if UIImagePickerController.isSourceTypeAvailable(.camera) { actionSheet.addAction(cameraAction) }
        actionSheet.addAction(selectedAlbumAtion)
        //if addButtonImageView.isHidden { actionSheet.addAction(deleteAction) }
        actionSheet.addAction(cancelAction)
        actionSheet.popoverPresentationController?.sourceView = view
        present(actionSheet, animated: true, completion: nil)
    }

}

extension RegistProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // 写真が選択された時に呼ばれる
    //func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        //let avatar = info[UIImagePickerController.InfoKey(rawValue: UIImagePickerController.InfoKey.editedImage.rawValue) ?? <#default value#>] as? UIImage
        //self.profileImageButton.setImage(avatar, for: .normal)
        //if let image = avatar {
        if let image = info[.editedImage] as? UIImage {
            self.uploadImage(image)
        }
        // 前の画面に戻る
        dismiss(animated: true, completion: nil)
    }
}

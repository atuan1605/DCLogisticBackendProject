//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor

enum AppError: String, Error {
    case invalidScope
    case invalidJWTIssuer
    case invalidPassword
    case usernameNotFound

    case invalidInput
    case expiredRefreshToken
    case itemCantBeChange
    case dontHaveEnoughDepositToProcess

    // Tracking Item
    case permissionDenied
    case trackingNumberAlreadyOnSystem
    case trackingNumbersAlreadyOnSystem
    case invalidAgentCodeForChain
    case cantRevertToRepackingIfItemNotRepacked
    case cantUpdateAgentCodeToNilIfPassedRepacking
    case statusUpdateInvalid
    case trackingItemNotFound
    case trackingItemReferenceNotFound
    case invalidStatus
    case customerCodeNotFound
    case itemDoesntHaveCustomerCode
    case agentCodeDoesntMatch
    case customerCodeDoesntMatch
    case itemIsNotEnoughInformation
    case invalidCustomerCodeForChain
    case thereIsItemInChainThatHasNotBeenUpdated
    case customerCodeDoesntMatchInChain
    case trackingItemNotAllowedToScan
    case trackingItemIsInReturnRequest
    case settingAlternativeRefIsOnlySuportedForWalmartTrackings
    case brokenProductDescriptionMustNotBeEmpty
    case trackingAlreadyInBox
    case trackingStatusIsntInBoxedAt
    case trackingHasManyCustomers
    case invalidStatusToRemoveTrackingFromChain
    case trackingHasManyPieces
    case cannotHoldTrackingAfterBeingBoxed
    // Tracking Item Piece
    case trackingItemPieceNotFound
    case notAllowedToDeleteThisPiece
    case cantAddProductToTrackingItem
    case trackingPieceIsInFlyingBack
    case trackingPieceNotAllowedToChangeBox
    // Product
    case cantAddProductToTrackingItemBelowRepacking
    case productNotFound
    case cannotExtractPackingVideo
    
    //shipment
    case shipmentIsCompleted
    case shipmentIsEmpty
    case shipmentNotFound
    case unfinishedShipment
    
    // Box
    case boxIsContainingReturnedItem
    case itemAlreadyExists
    case unknown
    case boxNotFound
    case boxIDIsNil
    case boxCustomItemNotFound
    case boxIsEmpty
    case boxWasInShipment
    
    // PackBox
    case packBoxNotFound
    case unfinishedPackBox
    case packBoxIsCompleted
    case packBoxIsEmpty
    
    // Delivery
    case deliveryNotFound
    case deliveryIsCompleted
    case unfinishedDelivery
    case deliveryIsEmpty
    
    // ThirdParty
    case invalidDCClientBaseURL
    case failedToUploadByLine
    case failedToNotifyFaultyTrackingItem
    
    //agent
    case agentCodeNotFound
    
    //customer
    case customerNotFound
    case customerCodeAlreadyExists
    case invalidPhoneNumber
    case customerAlreadyHaveEmail
    
    //scope
    case scopeAlreadyExists
    
    //warehouse
    case warehouseDoesntExist

    // Price
    case customerPriceNotFound
    
    //Agent
    case agentNotFound
    
    //WareHouse
    case warehouseNotFound
    
    //lot
    case lotNotFound
    
    //user
    case userCantSelfUpdate
    case confirmPasswordDoesntMatch
    case userResetPasswordTokenNotFound
    case disabledUser
    case userNotfound
    
    //buyer
    case buyerNotVerified
    case buyerNotFound
    
    //buyerTrackingItem
    case buyerTrackingItemNotFound
    
    //camera
    case cameraNotFound
    case cameraNotSupportInThisWarehouse
    
    //VideoDownloadingJob
    case videoDownloadingJobNotFound
    
    //Label
    case labelNotFound
    case subLabelCantBeUpdated
    
    //labelProduct
    case labelProductIsAlreadyExisted
    case labelProductNotFound
}

extension AppError: AbortError {
    var reason: String {
        return self.rawValue
    }

    var status: HTTPResponseStatus {
        switch self {
        case .invalidPassword, .invalidJWTIssuer, .invalidScope, .expiredRefreshToken:
            return .unauthorized
        case
                .usernameNotFound,
                .invalidStatus,
                .labelNotFound,
                .invalidInput,
                .subLabelCantBeUpdated,
                .trackingHasManyPieces,
                .packBoxIsEmpty,
                .cantAddProductToTrackingItemBelowRepacking,
                .labelProductIsAlreadyExisted,
                .invalidAgentCodeForChain,
                .customerAlreadyHaveEmail,
                .itemAlreadyExists,
                .shipmentIsCompleted,
                .buyerTrackingItemNotFound,
                .unfinishedShipment,
                .cameraNotFound,
                .invalidStatusToRemoveTrackingFromChain,
                .shipmentIsEmpty,
                .buyerNotVerified,
                .userNotfound,
                .customerCodeDoesntMatch,
                .itemCantBeChange,
                .userResetPasswordTokenNotFound,
                .deliveryIsCompleted,
                .unfinishedDelivery,
                .itemIsNotEnoughInformation,
                .cannotHoldTrackingAfterBeingBoxed,
                .unfinishedPackBox,
                .permissionDenied,
                .boxIsContainingReturnedItem,
                .packBoxIsCompleted,
                .deliveryIsEmpty,
                .boxWasInShipment,
                .itemDoesntHaveCustomerCode,
                .agentCodeDoesntMatch,
                .cantRevertToRepackingIfItemNotRepacked,
                .cantUpdateAgentCodeToNilIfPassedRepacking,
                .statusUpdateInvalid,
                .trackingAlreadyInBox,
                .trackingStatusIsntInBoxedAt,
                .boxIDIsNil,
                .buyerNotFound,
                .cantAddProductToTrackingItem,
                .scopeAlreadyExists,
                .trackingPieceIsInFlyingBack,
                .invalidCustomerCodeForChain,
                .confirmPasswordDoesntMatch,
                .thereIsItemInChainThatHasNotBeenUpdated,
                .trackingNumberAlreadyOnSystem,
                .customerCodeDoesntMatchInChain,
                .customerCodeAlreadyExists,
                .trackingNumbersAlreadyOnSystem,
                .invalidPhoneNumber,
                .disabledUser,
                .trackingItemNotAllowedToScan,
                .boxIsEmpty,
                .trackingPieceNotAllowedToChangeBox,
                .lotNotFound,
                .userCantSelfUpdate,
                .warehouseDoesntExist,
                .trackingItemReferenceNotFound,
                .settingAlternativeRefIsOnlySuportedForWalmartTrackings,
                .agentNotFound,
                .warehouseNotFound,
                .videoDownloadingJobNotFound,
                .trackingItemPieceNotFound,
                .notAllowedToDeleteThisPiece,
                .brokenProductDescriptionMustNotBeEmpty,
                .trackingItemIsInReturnRequest,
                .trackingHasManyCustomers,
                .cannotExtractPackingVideo,
                .labelProductNotFound,
                .dontHaveEnoughDepositToProcess,
                .cameraNotSupportInThisWarehouse:
            return .badRequest
        case
                .productNotFound,
                .shipmentNotFound,
                .boxNotFound,
                .trackingItemNotFound,
                .customerPriceNotFound,
                .agentCodeNotFound,
                .customerNotFound,
                .packBoxNotFound,
                .deliveryNotFound,
                .customerCodeNotFound,
                .boxCustomItemNotFound:
            return .notFound
        case .unknown, .invalidDCClientBaseURL, .failedToUploadByLine, .failedToNotifyFaultyTrackingItem:
            return .internalServerError
        }
    }
}


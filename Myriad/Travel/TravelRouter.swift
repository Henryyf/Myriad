//
//  TravelRouter.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import Foundation

enum TravelRoute: Hashable {
    case list
    case map
    case detail(UUID)   
}

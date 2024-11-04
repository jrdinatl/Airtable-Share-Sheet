//
//  Configuration.swift
//  Airtable ShareSheet
//
//  Created by thewiseacre on 11/3/24.
//


import Foundation

// Make it public to ensure visibility across the module
public struct Configuration {
    public static let airtableApiKey = "patyYl0UN5pzaj7SO.ed8727b78edca551908a84311a3bc2dea58ad802f9bf07c5ec8f420aff4731ee"
    public static let airtableBaseId = "app65i3Z1E0LL3Min"
    public static let airtableTableName = "tblWaT87C2KQTTXI5"
    
    public struct Fields {
        public static let url = "URL"
        public static let notes = "Notes"
        public static let attachments = "Attachments"
        public static let title = "Title"
    }
    
    public static let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB max file size
}
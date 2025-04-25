//
//  JournalEntryItemView.swift
//  Rebound Journal
//
//  Created by hyunho lee on 12/7/24.
//

import SwiftUI

struct JournalEntryItemView: View {
    let model: JournalEntry

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                JournalEntryHeaderView(model: model)
                
                if let entryText = model.moodText {
                    Text(entryText)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.text)
                }
                
                Color.dark.frame(height: 1).opacity(0.5)
                
                if let entryText = model.reboundText {
                    Text(entryText)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 20, weight: .regular))
                        .padding(.bottom, 10)
                        .foregroundColor(.text)
                }
                
                if let entryText = model.date?.longFormat {
                    Text(entryText)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 20, weight: .regular))
                        .padding(.bottom, 10)
                        .foregroundColor(.text)
                }
            }
            .padding([.top, .horizontal])
            JournalEntryPhotosView(model: model)
            JournalEntryFooterView(model: model)
        }
        .background(
            Color.list.cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.dark, lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct JournalEntryHeaderView: View {
    @EnvironmentObject var manager: DataManager
    let model: JournalEntry

    var body: some View {
        HStack(alignment: .top) {
            Image("level\(model.moodLevel)")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
                .frame(width: 50, height: 50, alignment: .center)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(Constants.Strings.myMood)
                    .font(.system(size: 16, weight: .light))
                if let mood = model.moodText?.uppercased() {
                    Text(mood)
                        .font(.system(size: 20, weight: .bold))
                }
            }
            
            Spacer()
            
            if model.moodLevel == 2 {
                Spacer()
                Button {
                    manager.fullScreenMode = .reboundCreator
                    manager.seledtedEntry = model
                } label: {
                    ZStack {
                        Color.diaryBackground
                            .cornerRadius(10)
                        Text(Constants.Strings.reShootIn)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.light)
                    }
                }
                .disabled(model.isRebounded)
                .opacity(model.isRebounded ? 0.3 : 1)
                .frame(width: 88, height: 42)
            }
        }
        .foregroundColor(.text)
    }
}

import SwiftUI

struct JournalEntryPhotosView: View {
    @EnvironmentObject var manager: DataManager
    var model: JournalEntry

    var body: some View {
        let width = UIScreen.main.bounds.width - 60

        ZStack {
            if let modelId = model.id,
               let images = manager.loadImages(id: modelId),
               images.count > 0 {

                ZStack {
                    if images.count == 1 {
                        EntryImageView(image: images[0], width: width, height: width / 2)
                    } else if images.count == 2 {
                        HStack(spacing: 5) {
                            EntryImageView(image: images[0], width: width / 2 - 5, height: width / 2)
                            EntryImageView(image: images[1], width: width / 2 - 5, height: width / 2)
                        }
                    } else if images.count == 3 || images.count == 4 {
                        HStack(spacing: 5) {
                            VStack(spacing: 5) {
                                EntryImageView(image: images[0], width: width / 2 - 5, height: width / 2 - 5)
                                EntryImageView(image: images[1], width: width / 2 - 5, height: width / 2 - 5)
                            }
                            if images.count == 3 {
                                EntryImageView(image: images[2], width: width / 2 - 5, height: width - 5)
                            } else {
                                VStack(spacing: 5) {
                                    EntryImageView(image: images[2], width: width / 2 - 5, height: width / 2 - 5)
                                    EntryImageView(image: images[3], width: width / 2 - 5, height: width / 2 - 5)
                                }
                            }
                        }
                    }
                }
                .cornerRadius(16)
                .padding(.bottom, 10)
            }
        }
    }
}


struct EntryImageView: View {
    @EnvironmentObject var manager: DataManager
    var image: UIImage
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height, alignment: .center)
            .clipped()
            .onTapGesture {
                if let imageName = image.accessibilityIdentifier?.replacingOccurrences(of: "-thumbnail", with: "") {
                    manager.selectedEntryImage = manager.loadImage(id: imageName)
                }
            }
    }
}


struct JournalEntryFooterView: View {
    let model: JournalEntry

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 10)
        .opacity(0.7)
    }
}

struct EmptyListView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "list.star")
                .font(.largeTitle)
                .padding(2)
            Text(Constants.Strings.noEntriesYet)
                .font(.title3)
                .bold()
            Text(Constants.Strings.noEntriesYetDiscription)
                .font(.subheadline)
                .opacity(0.6)
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .foregroundColor(.text)
    }
}


//#Preview {
//    JournalEntryItemView(model: JournalEntry.dummy)
//}


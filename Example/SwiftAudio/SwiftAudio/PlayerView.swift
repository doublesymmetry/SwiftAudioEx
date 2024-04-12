//
//  PlayerView.swift
//  SwiftAudio
//
//  Created by Brandon Sneed on 3/30/24.
//

import SwiftUI
import SwiftAudioEx

struct PlayerView: View {
    @ObservedObject var viewModel: ViewModel
    @State private var showingQueue = false

    let controller = AudioController.shared

    init(viewModel: PlayerView.ViewModel = ViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Spacer()
                Button(action: { showingQueue.toggle() }, label: {
                    Text("Queue")
                        .fontWeight(.bold)
                })
            }

            if let image = viewModel.artwork {
#if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(.top, 30)
#elseif os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(.top, 30)
#endif
            } else {
                AsyncImage(url: nil)
                    .frame(width: 240, height: 240)
                    .padding(.top, 30)
            }

            VStack(spacing: 4) {
                Text(viewModel.title)
                    .fontWeight(.semibold)
                    .font(.system(size: 18))
                Text(viewModel.artist)
                    .fontWeight(.thin)
            }
            .padding(.top, 30)

            if viewModel.maxTime > 0 {
                VStack {
                    Slider(value: $viewModel.position, in: 0...viewModel.maxTime) { editing in
                        viewModel.isScrubbing = editing
                        print("scrubbing = \(viewModel.isScrubbing)")
                        if viewModel.isScrubbing == false {
                            controller.player.seek(to: viewModel.position)
                        }
                    }
                    HStack {
                        Text(viewModel.elapsedTime)
                            .font(.system(size: 14))
                        Spacer()
                        Text(viewModel.remainingTime)
                            .font(.system(size: 14))
                    }
                }
                .padding(.top, 25)
            } else {
                Text("Live Stream")
                    .padding(.top, 35)
            } 

            HStack {
                Button(action: controller.player.previous, label: {
                    Text("Prev")
                        .font(.system(size: 14))
                })
                .frame(maxWidth: .infinity)

                Button(action: {
                    if viewModel.playing {
                        controller.player.pause()
                    } else {
                        controller.player.play()
                    }
                }, label: {
                    Text(!viewModel.playWhenReady || viewModel.playbackState == .failed ? "Play" : "Pause")
                        .font(.system(size: 18))
                        .fontWeight(.semibold)
                })

                .frame(maxWidth: .infinity)
                Button(action: controller.player.next, label: {
                    Text("Next")
                        .font(.system(size: 14))
                })
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 80)

            VStack {
                if viewModel.playbackState == .failed {
                    Text("Playback failed.")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.top, 20)
                } else if (viewModel.playbackState == .loading || viewModel.playbackState == .buffering) && viewModel.playWhenReady {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .padding(.top, 20)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showingQueue) {
            QueueView()
#if os(macOS)
                .frame(width: 300, height: 400)
#endif
        }
        .padding(.horizontal, 16)
        .padding(.top)
    }
}

#Preview("Standard") {
    let viewModel = PlayerView.ViewModel()
    viewModel.title = "Longing"
    viewModel.artist = "David Chavez"

    return PlayerView(viewModel: viewModel)
}

#Preview("Error") {
    let viewModel = PlayerView.ViewModel()
    viewModel.title = "Longing"
    viewModel.artist = "David Chavez"
    viewModel.playbackState = .failed

    return PlayerView(viewModel: viewModel)
}

#Preview("Buffering") {
    let viewModel = PlayerView.ViewModel()
    viewModel.title = "Longing"
    viewModel.artist = "David Chavez"
    viewModel.playbackState = .buffering
    viewModel.playWhenReady = true

    return PlayerView(viewModel: viewModel)
}

#Preview("Live Stream") {
    let viewModel = PlayerView.ViewModel()
    viewModel.title = "Longing"
    viewModel.artist = "David Chavez"
    viewModel.maxTime = 0

    return PlayerView(viewModel: viewModel)
}

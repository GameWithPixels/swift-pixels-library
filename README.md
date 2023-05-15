# PixelsLibrary

Welcome to the Pixels Library for Apple operating systems documentation!
The supported OSes are MacOS >= 10.15 and iOS >= 13.

This [repository](https://github.com/GameWithPixels/PixelsAppleOS)
contains the source code of the Pixels Library for Apple Operating Systems
along with an example app that runs on iOS and MacOS.

For the library documentation, open the project in XCode, select the "PixelsLibrary" scheme
and build the documentation from the "Product" menu.

## Overview

This library supports scanning for and connecting to Pixels Bluetooth peripherals.

When not connected to a device, a Pixels die periodically emits information about
its current state. This typically occurs a few times per second.
This piece of data is called an [advertisement](
    https://www.bluetooth.com/bluetooth-resources/intro-to-bluetooth-advertisements/
) packet in the Bluetooth specifications.

This data is decoded and stored in ``ScannedPixel`` objects and can be used to retrieve
information about a Pixels die without connecting to it.
However, if not moved, the die will turn off automatically after a short delay and so
it will stop emitting advertisement packets.

Use the ``PixelScanner/shared`` global object to start and stop Bluetooth scans.
This object maintains a list of scanned Pixels in ``PixelScanner/scannedPixels`
that can be observed for changes.

See the ``PixelScanner`` class for more information.

To start monitoring rolls or other information from a Pixels die, the application first need
to connect to the die.
Use the corresponding instance of a ``Pixel`` class to connect to a die and communicate with it.

The ``PixelScanner/getPixel(_:)`` function returns the ``Pixel`` instance for a given die.

Connect to the die with the asynchronous ``Pixel/connect()`` function and and observe the changes
of the ``Pixel/rollState`` property to get notified when the die is rolled.
This property value will be set to `PixelRollState/onFace` whenever the die finishes a roll.
Read the ``Pixel/currentFace`` property to get the face value of the roll.

Due to the asynchronous nature of Bluetooth communications, the different properties
of a ``Pixel`` instance might update at any time, including the ``Pixel/status``
which indicates the last know connection status with the die.
It is not necessary to check the status of the die before sending a message or making other
requests this status might change between the time it was checked and the time a call is made
to reach out to the die.

Instead it is recommended to observe the ``Pixel/status`` value for changes to be notified
when a disconnection occurs.

To read more about the asynchronous nature of communications with Pixels dice see the
`pixels-web-connect` package [documentation](
    https://gamewithpixels.github.io/pixels-js/modules/_systemic_games_pixels_web_connect.html
).
Even though this documentation is for Typescript/JavaScript, the Pixel class in this package is
very similar to the one in this Swift library.

See the ``Pixel`` class for more information.

## Example App

An example app working for both MacOS and iOS is available in the package's `PixelsExampleApp`
directory.

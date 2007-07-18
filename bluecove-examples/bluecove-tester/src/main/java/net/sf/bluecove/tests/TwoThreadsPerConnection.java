/**
 *  BlueCove - Java library for Bluetooth
 *  Copyright (C) 2006-2007 Vlad Skarzhevskyy
 * 
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *  @version $Id$
 */ 
package net.sf.bluecove.tests;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import junit.framework.Assert;

import net.sf.bluecove.Logger;
import net.sf.bluecove.ConnectionHolderStream;
import net.sf.bluecove.util.TimeUtils;

/**
 * Test two directional Stream.
 * Create Second Thread to Write to connection.
 * Main Test thread will read data sent by connected party.
 * Test is symmetrical in regards to client and server.
 * @author vlads
 *
 */
public class TwoThreadsPerConnection {

	private static final int DATA_SIZE = 8 * 1024;
	
	private int arraySize;
	
	private boolean synchronize;
	
	private int iterations;
	
	private int bytesTotal;
	
	private int sentCount = 0;
	
	private int receivedCount = 0;
	
	private boolean stoped = false;
	
	private class WriteTread extends Thread {
		
		OutputStream os;
		
		boolean isRunning;
		
		boolean sendFinishedSuccessfully = false;
		
		public void run() {
			try {
				isRunning = true;
				sendingData(os);
				sendFinishedSuccessfully = true;
			} catch (IOException e) {
				Logger.error("Sending", e);
			} finally {
				isRunning = false;
			}
		}
		
	}

	WriteTread startSender(OutputStream os) {
		WriteTread t = new WriteTread();
		t.os = os;
		t.start();
		return t;
	}

	void equalizeWrite() {
		while ((!stoped) && (sentCount - receivedCount > 256)) {
			try {
				Thread.sleep(50);
			} catch (InterruptedException e) {
				Assert.fail("interrupted");
			}
		}
	}
	
	void sendingData(OutputStream os) throws IOException {
		long start = System.currentTimeMillis();
		long reported = start; 
		int k = 0;
		for(int i = 1; (!stoped) && i <= iterations; i++) {
			if (arraySize == 1) {
				os.write((byte)i);
				if (i % 64 == 0) {
					os.flush();
				}
			} else {
				byte[] data = new byte[arraySize];
				for(int j = 0; j < arraySize; j ++, k ++) {
					data[j] = (byte)k;
				}
				os.write(data);
				if (i % 2 == 0) {
					os.flush();
				}
			}
			sentCount +=arraySize;
			if ((i % 100 == 0) && (TimeUtils.since(reported) > 10000)) {
				Logger.debug("sent " + sentCount + " bytes in " + TimeUtils.secSince(start));
				reported = System.currentTimeMillis();
			}
			if (synchronize) {
				equalizeWrite();
			}
		}
		if (!stoped) {
			Logger.debug("speed " + TimeUtils.bps(sentCount, start));
		}
	}

	void readingData(InputStream is, ConnectionHolderStream c) throws IOException {
		int k = 0;
		for (int i = 1; i <= iterations; i++) {
			try {
				if (arraySize == 1) {
					byte got = (byte)is.read();
					Assert.assertEquals("byte read [" + i + "]", (byte) i, got);
					receivedCount++;
				} else {
					byte[] data = new byte[arraySize];
					int len = arraySize;
					int read_off = 0;
					while (len != 0) {
						int rcvd = is.read(data, read_off, len);
						if (rcvd == -1) {
							throw new IOException("EOF not expected");
						}
						len -= rcvd;
						read_off += rcvd;
					}
					for(int j = 0; j < arraySize; j ++, k ++) {
						Assert.assertEquals("byte read [" + k + "]", (byte)k, data[j]);
					}
					receivedCount += arraySize;
				}
			} catch (IOException e) {
				Logger.debug("Received only " + receivedCount + " bytes");
				throw e;
			}
			c.active();
		}
	}
	
	public static void start(ConnectionHolderStream c, int arraySize, boolean synchronize) throws IOException {
		TwoThreadsPerConnection worker = new TwoThreadsPerConnection();
		worker.synchronize = synchronize;
		worker.arraySize = arraySize;
		if (arraySize == 1) {
			worker.bytesTotal = DATA_SIZE;
			worker.iterations = worker.bytesTotal;
		} else {
			worker.iterations = DATA_SIZE / arraySize;
			worker.bytesTotal = worker.iterations * arraySize;
		}
		
		WriteTread sender = worker.startSender(c.os);
		try {
			worker.readingData(c.is, c);
			try {
				if (sender.isRunning) {
					sender.join();
				}
			} catch (InterruptedException e) {
				Assert.fail("interrupted");
			}
		} finally {
			worker.stoped = true;
		}
		Assert.assertEquals("sentCount", worker.bytesTotal, worker.sentCount);
		Assert.assertTrue("sendFinishedSuccessfully", sender.sendFinishedSuccessfully);
		
	}
}

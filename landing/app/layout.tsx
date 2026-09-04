import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const geistMono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });

export const metadata: Metadata = {
  metadataBase: new URL('https://schnapshot.com'),
  title: 'SchnapShot — Screenshot to site-ready image',
  description: 'Open-source Mac app for turning screenshots into thumbnails, Open Graph images, and icons with your own Codex account. Save prompts and exact output sizes.',
  applicationName: 'SchnapShot',
  alternates: { canonical: 'https://schnapshot.com/' },
  icons: {
    icon: [{ url: '/favicon.png', type: 'image/png', sizes: '32x32' }],
    apple: [{ url: '/apple-touch-icon.png', sizes: '180x180' }],
  },
  openGraph: {
    type: 'website',
    url: 'https://schnapshot.com/',
    siteName: 'SchnapShot',
    title: 'SchnapShot — Your screenshot. Sized for the web.',
    description: 'Capture an area. Generate a site-ready image with your own Codex account. Copy and go. Open source for macOS.',
    locale: 'en_US',
  },
  twitter: {
    card: 'summary',
    title: 'SchnapShot — Your screenshot. Sized for the web.',
    description: 'Open-source Mac app. Your Codex account. Thumbnails, Open Graph images, and icons at the exact size you need.',
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className={`${geistSans.variable} ${geistMono.variable}`}>{children}</body></html>;
}

import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RealityRostr",
  description: "Fantasy leagues for reality competition TV.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
